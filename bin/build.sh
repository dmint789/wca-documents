#!/bin/bash

wca_url="https://www.worldcubeassociation.org/"
wca_docs_url="https://documents.worldcubeassociation.org/"
# Absolute paths to the logo file, the main stylesheet and the edudoc header
logo=$(realpath "./assets/WCAlogo_notext.svg")
main_stylesheet=$(realpath "./assets/style.css")
edudoc_header=$(realpath "./assets/edudoc-header.html")
# Current date
compile_date=$(date '+%Y-%m-%d')

# Function for converting Markdown files from a given directory into PDF files.
# The first argument ($1) refers to the directory name (e.g: documents or edudoc).
convert_to_pdf() {
  cp -r "$1/" build/

  # Find Markdown files and build PDFs out of them.
  find "build/$1" -name '*.md' | while read file; do
    echo "Converting ${file#build/}..."

    pdf_path="${file%.md}.pdf"
    html_path="${file%.md}.html"
    # Use first header as the document title; remove all # characters and whitespace from the beginning
    document_title=$(head -n 1 "$file" | sed -E "s/^#+\s*//")
    # Absolute path to the custom stylesheet
    custom_stylesheet=$(realpath "./assets/$1-style.css")

    # Replace wca{...} and wcadoc{...} with absolute WCA URLs (the correct URLs only get inserted in production)
    sed -Ei "s#wca\{([^}]*)\}#$wca_url\1#g" "$file"
    sed -Ei "s#wcadoc\{([^}]*)\}#$wca_docs_url\1#g" "$file"
    # Replace {logo} with the path to the WCA logo in /assets
    sed -Ei "s#\{logo\}#$logo#g" "$file"

    # This creates the custom header for each edudoc and prepends it to each file
    if [ "$1" = "edudoc" ]; then
      # Set the document title, path to the logo and the date
      sed -E "s#\{document_title\}#$document_title#g" "$edudoc_header" |
      sed -E "s#\{wca_logo_path\}#$logo#g" |
      sed -E "s#\{date\}#$compile_date#g" |
      echo -e "$(cat /dev/stdin)\n\n$(cat $file)" > "$file"
    fi

    # Markdown => HTML + remove unsupported styles generated by pandoc
    pandoc -s --from markdown --to html5 --css "$main_stylesheet" --css "$custom_stylesheet" --metadata pagetitle="$document_title" "$file" |
    sed -E "s#gap: min\(4vw, 1\.5em\);##" |
    sed -E "s#overflow-x: auto;##" > "$html_path"

    # HTML -> PDF
    if [ "$1" = "documents" ]; then
      weasyprint --presentational-hints --encoding 'utf-8' "$html_path" "$pdf_path"
    elif [ "$1" = "edudoc" ]; then
      weasyprint --presentational-hints --encoding 'utf-8' "$html_path" "$pdf_path"
    fi
  done
}

# Delete all contents of the build directory and create it if it didn't exist in the first place
rm -rf build/*
mkdir -p build

# Use the DIRECTORY_TO_BUILD environment variable or the passed argument as the only directory
# that will have its documents built. If neither is set, fall back to building all directories.
if [ -n "$DIRECTORY_TO_BUILD" ]; then
  convert_to_pdf "$DIRECTORY_TO_BUILD"
elif [ -n "$1" ]; then
  convert_to_pdf "$1"
else
  convert_to_pdf documents
  convert_to_pdf edudoc
fi

# Remove all non-PDF files and empty directories from build
find build/ -type f -not -name "*.pdf" -delete
find build/ -type d -empty -delete

echo -e "\nBuild finished!"

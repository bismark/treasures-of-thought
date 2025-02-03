import os
import pytesseract
from PIL import Image
import re
import shutil

# Folder where original images are stored
image_folder = "split_images"
output_folder = "renamed_images"

# Ensure output directory exists
os.makedirs(output_folder, exist_ok=True)

# Month-to-number mapping
month_mapping = {
    "January": "01", "February": "02", "March": "03", "April": "04",
    "May": "05", "June": "06", "July": "07", "August": "08",
    "September": "09", "October": "10", "November": "11", "December": "12"
}

# Iterate over image files
for filename in os.listdir(image_folder):
    if filename.endswith(".png"):
        image_path = os.path.join(image_folder, filename)
        
        # Perform OCR on the image
        text = pytesseract.image_to_string(Image.open(image_path))

        # Find the date in text (expects "Month DD" format)
        match = re.search(r"(January|February|March|April|May|June|July|August|September|October|November|December) (\d{1,2})", text)
        
        if match:
            month, day = match.groups()
            month_number = month_mapping[month]
            formatted_name = f"{month_number}-{int(day):02}.png"
            new_path = os.path.join(output_folder, formatted_name)
            
            # Copy file with new name (keeping original)
            shutil.copy(image_path, new_path)
            print(f"Copied: {filename} → {formatted_name}")

print("Renaming complete! Check the 'renamed_images' folder.")


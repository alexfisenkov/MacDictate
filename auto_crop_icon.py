import os
import subprocess
import sys
from PIL import Image, ImageDraw

def create_icns(source_png, output_dir="MyIcon_Cropped.iconset"):
    # Load and convert image
    img = Image.open(source_png).convert("RGBA")
    
    # AI generated images usually have thick white padding around a colored squricle.
    # We will detect the true bounding box by finding non-white pixels.
    bg = Image.new("RGBA", img.size, (255, 255, 255, 255))
    diff = Image.composite(img, bg, img)
    # Convert diff to grayscale to easily detect edges
    grayscale = diff.convert("L")
    # Invert so white becomes black (0), and colored content becomes non-zero
    from PIL import ImageOps
    inverted = ImageOps.invert(grayscale)
    bbox = inverted.getbbox() # Returns (left, upper, right, lower)
    
    if bbox:
        # Give a very tiny 2% padding so it doesn't touch the edge perfectly
        padding = int((bbox[2] - bbox[0]) * 0.02)
        crop_box = (
            max(0, bbox[0] - padding),
            max(0, bbox[1] - padding),
            min(img.width, bbox[2] + padding),
            min(img.height, bbox[3] + padding)
        )
        img = img.crop(crop_box)
    else:
        print("Could not find a crop mask, using raw image.")
        
    width, height = img.size
    
    # We want to force a beautiful macOS-style Squircle (Rounded Rect) with transparent corners
    # The standard macOS radius is about 22.5% of the width.
    mask = Image.new('L', img.size, 0)
    draw = ImageDraw.Draw(mask)
    radius = int(width * 0.225)
    draw.rounded_rectangle((0, 0, width, height), radius=radius, fill=255)
    
    # Apply alpha mask
    final_img = Image.new('RGBA', img.size)
    final_img.paste(img, (0, 0), mask)

    # Now generate the ICNS sizes
    if os.path.exists(output_dir):
        import shutil
        shutil.rmtree(output_dir)
    os.makedirs(output_dir)

    sizes = [16, 32, 64, 128, 256, 512, 1024]
    
    for size in sizes:
        resized = final_img.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(os.path.join(output_dir, f"icon_{size}x{size}.png"))
        if size <= 512:
            resized_2x = final_img.resize((size * 2, size * 2), Image.Resampling.LANCZOS)
            resized_2x.save(os.path.join(output_dir, f"icon_{size}x{size}@2x.png"))

    print("Generating ICNS...")
    subprocess.check_call(["iconutil", "-c", "icns", output_dir])
    
    import shutil
    shutil.copy("MyIcon_Cropped.icns", "assets/AppIcon.icns")
    print("SUCCESS: Cropped transparent Apple Icon generated!")

if __name__ == "__main__":
    png_path = "/Users/AlexFisenkov_1/.gemini/antigravity/brain/b7794457-ca76-4039-859d-9561a44e645f/macdictate_icon_1774954155536.png"
    create_icns(png_path)

import os
import subprocess
import sys

def create_icns(source_png, output_dir="MyIcon.iconset"):
    try:
        from PIL import Image
    except ImportError:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "Pillow", "--break-system-packages"])
        from PIL import Image

    if os.path.exists(output_dir):
        import shutil
        shutil.rmtree(output_dir)
    os.makedirs(output_dir)

    sizes = [16, 32, 64, 128, 256, 512, 1024]
    
    img = Image.open(source_png).convert("RGBA")
    
    for size in sizes:
        # Save standard resolution
        resized = img.resize((size, size), Image.Resampling.LANCZOS)
        resized.save(os.path.join(output_dir, f"icon_{size}x{size}.png"))
        
        # Save @2x resolution (for Retina displays)
        if size <= 512:
            resized_2x = img.resize((size * 2, size * 2), Image.Resampling.LANCZOS)
            resized_2x.save(os.path.join(output_dir, f"icon_{size}x{size}@2x.png"))

    print("PNGs generated using Pillow. Running iconutil...")
    subprocess.check_call(["iconutil", "-c", "icns", output_dir])
    
    import shutil
    shutil.copy("MyIcon.icns", "assets/AppIcon.icns")
    print("SUCCESS: assets/AppIcon.icns created.")

if __name__ == "__main__":
    png_path = "/Users/AlexFisenkov_1/.gemini/antigravity/brain/b7794457-ca76-4039-859d-9561a44e645f/macdictate_icon_1774954155536.png"
    create_icns(png_path)

import sys
from PIL import Image, ImageDraw, ImageFont

def generate_background():
    # Window size is 600x400
    width, height = 600, 400
    # Soft beautiful background color (very light gray/blue)
    bg = Image.new('RGB', (width, height), '#f5f7fa')
    draw = ImageDraw.Draw(bg)

    # We need to draw a big thick arrow from left (MacDictate) to right (Applications)
    # MacDictate is at 140, 190. Applications is at 460, 190
    # Center of arrow should be around 300, 190

    # Draw arrow body
    arrow_color = '#a0aabf' # Soft metallic blue/gray
    draw.rectangle([(230, 185), (330, 195)], fill=arrow_color)
    
    # Draw arrow head
    draw.polygon([(330, 170), (330, 210), (370, 190)], fill=arrow_color)
    
    # Try to load a nice font, otherwise use default
    try:
        # standard macOS San Francisco font
        font = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 30)
        font_sub = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 16)
    except Exception:
        font = ImageFont.load_default()
        font_sub = font

    # Draw text
    text = "Drag to Install"
    sub_text = "MacDictate -> Applications"
    
    # Center text horizontally above the arrow
    draw.text((220, 120), text, font=font, fill='#4a5568')
    
    # Optional subtext
    draw.text((215, 230), sub_text, font=font_sub, fill='#718096')

    bg.save('assets/dmg_background.png')
    print("Background 'assets/dmg_background.png' generated.")

if __name__ == '__main__':
    generate_background()

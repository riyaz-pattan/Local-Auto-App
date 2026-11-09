import os
from PIL import Image

def remove_white_bg(img, threshold=245):
    img = img.convert("RGBA")
    datas = img.getdata()
    new_data = []
    for item in datas:
        if item[0] >= threshold and item[1] >= threshold and item[2] >= threshold:
            new_data.append((255, 255, 255, 0)) # Transparent
        else:
            new_data.append(item)
    img.putdata(new_data)
    return img

def process_icon(input_path, output_dir):
    os.makedirs(output_dir, exist_ok=True)
    img = Image.open(input_path).convert("RGBA")
    
    subject = remove_white_bg(img, threshold=240)
    bbox = subject.getbbox()
    if bbox:
        subject = subject.crop(bbox)
        
    fg_size = 432
    fg_logo_size = int(432 * 0.70)
    
    subject_thumb = subject.copy()
    subject_thumb.thumbnail((fg_logo_size, fg_logo_size), Image.Resampling.LANCZOS)
    
    fg = Image.new("RGBA", (fg_size, fg_size), (0,0,0,0))
    fg.paste(subject_thumb, ((fg_size - subject_thumb.width)//2, (fg_size - subject_thumb.height)//2), subject_thumb)
    fg.save(os.path.join(output_dir, "icon_foreground.png"))
    
    bg = Image.new("RGBA", (fg_size, fg_size), (255, 255, 255, 255))
    bg.save(os.path.join(output_dir, "icon_background.png"))
    
    main_size = 1024
    main_img = Image.new("RGBA", (main_size, main_size), (255, 255, 255, 255))
    sub_1024 = subject.copy()
    sub_1024.thumbnail((int(main_size * 0.8), int(main_size * 0.8)), Image.Resampling.LANCZOS)
    main_img.paste(sub_1024, ((main_size - sub_1024.width)//2, (main_size - sub_1024.height)//2), sub_1024)
    main_img.save(os.path.join(output_dir, "icon_main.png"))
    
    splash_640 = Image.new("RGBA", (640, 640), (255, 255, 255, 255))
    sub_640 = subject.copy()
    sub_640.thumbnail((int(640 * 0.5), int(640 * 0.5)), Image.Resampling.LANCZOS)
    splash_640.paste(sub_640, ((640 - sub_640.width)//2, (640 - sub_640.height)//2), sub_640)
    splash_640.save(os.path.join(output_dir, "splash_640.png"))
    
    splash_1152 = Image.new("RGBA", (1152, 1152), (255, 255, 255, 255))
    sub_1152 = subject.copy()
    sub_1152.thumbnail((int(1152 * 0.4), int(1152 * 0.4)), Image.Resampling.LANCZOS)
    splash_1152.paste(sub_1152, ((1152 - sub_1152.width)//2, (1152 - sub_1152.height)//2), sub_1152)
    splash_1152.save(os.path.join(output_dir, "splash_1152.png"))

apps = {
    "rider": "/Users/rameez/.gemini/antigravity/brain/6d18cc5c-b61a-42b3-a28b-6857c20762be/rider_icon_concept_1790573934014.jpg",
    "driver": "/Users/rameez/.gemini/antigravity/brain/6d18cc5c-b61a-42b3-a28b-6857c20762be/driver_icon_concept_1790573948664.jpg",
    "admin": "/Users/rameez/.gemini/antigravity/brain/6d18cc5c-b61a-42b3-a28b-6857c20762be/admin_icon_concept_1790573960299.jpg"
}

base_dir = "/Users/rameez/Desktop/PROJECT-K"

for app, img_path in apps.items():
    out_dir = os.path.join(base_dir, app, "assets", "images", "logo")
    print(f"Processing {app}...")
    process_icon(img_path, out_dir)
print("Done!")

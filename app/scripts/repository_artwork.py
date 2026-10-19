#!/usr/bin/env python3
"""Recreate repository SVG artwork using the existing app icon's palette."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/github'


def banner(height):
    social = height == 640
    offset = 80 if social else 0
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="1280" height="{height}" viewBox="0 0 1280 {height}" role="img" aria-label="Projection Mapper. Make every surface a canvas.">
<defs>
  <linearGradient id="bg" x2="1" y2="1"><stop stop-color="#0a1228"/><stop offset="1" stop-color="#19213b"/></linearGradient>
  <linearGradient id="face"><stop stop-color="#d32cf0"/><stop offset="1" stop-color="#7a46ff"/></linearGradient>
  <pattern id="grid" width="48" height="48" patternUnits="userSpaceOnUse"><path d="M48 0H0V48" fill="none" stroke="#ffffff" stroke-opacity=".035"/></pattern>
</defs>
<rect width="1280" height="{height}" rx="24" fill="url(#bg)"/>
<rect width="1280" height="{height}" rx="24" fill="url(#grid)"/>
<g font-family="-apple-system, BlinkMacSystemFont, 'Helvetica Neue', Arial, sans-serif">
  <text x="64" y="{56+offset}" fill="#1ad1df" font-size="13" font-weight="600" letter-spacing="2.8">MAKE EVERY SURFACE A CANVAS</text>
  <text x="60" y="{151+offset}" fill="#ffffff" font-size="82" font-weight="700" letter-spacing="-3">Projection</text>
  <text x="60" y="{234+offset}" fill="#ffffff" font-size="82" font-weight="700" letter-spacing="-3">Mapper</text>
  <text x="65" y="{286+offset}" fill="#c7cfdf" font-size="25">Map. Animate. Rehearse.</text>
  <text x="65" y="{324+offset}" fill="#97a6be" font-size="18">A native Mac workspace for mapped visual effects.</text>
  <rect x="64" y="{355+offset}" width="139" height="34" rx="17" fill="#ffffff" fill-opacity=".075" stroke="#ffffff" stroke-opacity=".13"/>
  <text x="83" y="{377+offset}" fill="#e2e8f1" font-size="14">Native macOS</text>
  <rect x="214" y="{355+offset}" width="166" height="34" rx="17" fill="#ffffff" fill-opacity=".075" stroke="#ffffff" stroke-opacity=".13"/>
  <text x="234" y="{377+offset}" fill="#e2e8f1" font-size="14">SwiftUI · Metal</text>
</g>
<g transform="translate(820 {54+offset})">
  <ellipse cx="180" cy="310" rx="180" ry="18" fill="#000000" opacity=".18"/>
  <path d="M180 0L350 98L180 196L10 98Z" fill="#ff9326"/>
  <path d="M10 98L180 196V310L10 212Z" fill="url(#face)"/>
  <path d="M180 196L350 98V212L180 310Z" fill="#00c8d8"/>
  <path d="M10 157L180 255L350 157" stroke="#ffffff" stroke-width="7" fill="none"/>
  <g fill="#0c142a" stroke="#e7eefb" stroke-width="2"><circle cx="180" cy="0" r="5"/><circle cx="10" cy="98" r="5"/><circle cx="350" cy="98" r="5"/><circle cx="180" cy="310" r="5"/></g>
</g>
{'''<path d="M64 544H1216" stroke="#ffffff" stroke-opacity=".13"/>
<text x="64" y="586" fill="#9eabc1" font-family="-apple-system, Arial, sans-serif" font-size="20">github.com/Chosencode25/projection-mapper</text>''' if social else ''}
</svg>'''


def button(text, width, background, foreground):
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="46" role="img" aria-label="{text}"><rect x="1" y="1" width="{width-2}" height="44" rx="9" fill="{background}" stroke="{foreground}" stroke-opacity=".15"/><text x="{width/2}" y="29" text-anchor="middle" fill="{foreground}" font-size="15" font-weight="600" font-family="-apple-system, BlinkMacSystemFont, 'Helvetica Neue', Arial, sans-serif">{text}</text></svg>'''


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / 'hero.svg').write_text(banner(440))
    (OUT / 'social-preview.svg').write_text(banner(640))
    (OUT / 'download-stable.svg').write_text(button('Download stable · v1.15.1', 248, '#813bed', '#ffffff'))
    (OUT / 'build-latest.svg').write_text(button('Build latest · v2.01', 211, '#19213b', '#e6eaf2'))
    render_social()


def render_social():
    # Render the same vector design locally; Pillow is optional for SVG regeneration.
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        print('SVGs generated. Install Pillow to regenerate social-preview.png.')
        return
    scale = 2
    image = Image.new('RGB', (1280 * scale, 640 * scale))
    draw = ImageDraw.Draw(image)
    for y in range(640 * scale):
        t = y / (640 * scale)
        draw.line((0, y, 1280 * scale, y), fill=tuple(round(a+(b-a)*t) for a,b in zip((10,18,40),(25,33,59))))
    for x in range(0,1280,48): draw.line((x*scale,0,x*scale,640*scale),fill=(30,39,60))
    for y in range(0,640,48): draw.line((0,y*scale,1280*scale,y*scale),fill=(30,39,60))
    def polygon(points, fill): draw.polygon([(x*scale,y*scale) for x,y in points],fill=fill)
    def text(x,y,value,size,fill,bold=False):
        filename = 'Arial Bold.ttf' if bold else 'Arial.ttf'
        font=ImageFont.truetype('/System/Library/Fonts/Supplemental/'+filename,size*scale)
        draw.text((x*scale,y*scale),value,font=font,fill=fill,anchor='ls')
    text(64,136,'MAKE EVERY SURFACE A CANVAS',13,'#1ad1df',True)
    text(60,231,'Projection',82,'#ffffff',True)
    text(60,314,'Mapper',82,'#ffffff',True)
    text(65,366,'Map. Animate. Rehearse.',25,'#c7cfdf')
    text(65,404,'A native Mac workspace for mapped visual effects.',18,'#97a6be')
    for x,width,label in [(64,139,'Native macOS'),(214,166,'SwiftUI · Metal')]:
        draw.rounded_rectangle((x*scale,435*scale,(x+width)*scale,469*scale),radius=17*scale,fill='#29334b',outline='#3b455c',width=scale)
        text(x+19,457,label,14,'#e2e8f1')
    polygon([(1000,134),(1170,232),(1000,330),(830,232)],'#ff9326')
    polygon([(830,232),(1000,330),(1000,444),(830,346)],'#ca2bef')
    polygon([(1000,330),(1170,232),(1170,346),(1000,444)],'#00c8d8')
    draw.line([(830*scale,291*scale),(1000*scale,389*scale),(1170*scale,291*scale)],fill='white',width=7*scale)
    for x,y in [(1000,134),(830,232),(1170,232),(1000,444)]:
        draw.ellipse(((x-5)*scale,(y-5)*scale,(x+5)*scale,(y+5)*scale),fill='#0c142a',outline='#e7eefb',width=2*scale)
    draw.line((64*scale,544*scale,1216*scale,544*scale),fill='#3b455c',width=scale)
    text(64,586,'github.com/Chosencode25/projection-mapper',20,'#9eabc1')
    image.resize((1280,640),Image.Resampling.LANCZOS).save(OUT/'social-preview.png',optimize=True)


if __name__ == '__main__':
    main()

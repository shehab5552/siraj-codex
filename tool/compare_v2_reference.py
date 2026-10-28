#!/usr/bin/env python3
"""Offline HTML/Flutter evidence, not an automatic design-acceptance decision.
Requires Pillow, Playwright and a local Chromium. Never requests external URLs.
Run after flutter test --update-goldens test/v2_all_screens_golden_test.dart.
"""
import argparse
import base64
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageStat
from playwright.sync_api import sync_playwright

parser = argparse.ArgumentParser()
parser.add_argument('--repo', type=Path, default=Path(__file__).resolve().parents[1])
parser.add_argument('--chromium', default='/usr/bin/chromium')
parser.add_argument('--output', type=Path)
args = parser.parse_args()
repo = args.repo.resolve()
output = args.output or repo / 'docs/design/visual_verification_2026-10-29'
output.mkdir(parents=True, exist_ok=True)
source = repo / 'docs/design/reference_v2/SIRAJ_UIUX_REDESIGN_V2_INTERACTIVE.html'
goldens = repo / 'test/goldens/reference_v2'
font = repo / 'assets/fonts/NotoSansArabic.ttf'
rows = []
with sync_playwright() as playwright:
    browser = playwright.chromium.launch(executable_path=args.chromium,
                                        headless=True, args=['--no-sandbox'])
    page = browser.new_page(viewport={'width': 1280, 'height': 1000}, device_scale_factor=1)
    page.route('**/*', lambda route: route.abort())
    page.set_content(source.read_text(), wait_until='domcontentloaded')
    # Supply the exact font named by the original HTML using the app's local
    # asset. No reference layout/CSS behavior or science content is changed.
    encoded = base64.b64encode(font.read_bytes()).decode()
    page.add_style_tag(content="@font-face{font-family:'Noto Sans Arabic';src:url(data:font/ttf;base64,"
                       + encoded + ");font-weight:100 900}")
    page.evaluate('document.fonts.ready')
    for dark in (False, True):
        theme = 'dark' if dark else 'light'
        for name in ['onboard', 'auth', 'home', 'chat', 'history', 'library', 'quiz', 'resources', 'settings']:
            page.evaluate('(v)=>{state.dark=v.dark;navigate(v.name)}', {'dark': dark, 'name': name})
            screenshot = page.locator('.phone').screenshot()
            import io
            reference = Image.open(io.BytesIO(screenshot)).convert('RGB').crop((8, 34, 388, 771))
            actual_file = goldens / f'app_ar_{theme}_{name}.png'
            actual = Image.open(actual_file).convert('RGB')
            assert reference.size == actual.size == (380, 737)
            difference = ImageChops.difference(reference, actual)
            panel = Image.new('RGB', (1140, 769), 'white')
            for x, image, title in [(0, reference, 'Reference HTML'), (380, actual, 'Actual Flutter'),
                                    (760, difference, 'Absolute RGB difference')]:
                panel.paste(image, (x, 32))
                ImageDraw.Draw(panel).text((x + 8, 9), f'{name}/{theme} - {title}', fill='black')
            filename = f'{name}-{theme}-comparison.png'
            panel.save(output / filename)
            rows.append({'screen': name, 'theme': theme, 'viewport': '380x737@1',
                         'mae_rgb_0_255': round(sum(ImageStat.Stat(difference).mean) / 3, 3),
                         'panel': filename,
                         'same_production_data': False,
                         'note': 'Descriptive metric only. No approved pass threshold. Reference includes demo data.'})
    browser.close()
(output / 'metrics.json').write_text(json.dumps({'reference_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
    'font_sha256': hashlib.sha256(font.read_bytes()).hexdigest(), 'comparisons': rows}, indent=2) + '\n')
print(f'{len(rows)} comparison panels written. No automatic visual acceptance claimed.')

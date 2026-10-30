#!/usr/bin/env python3
"""Offline, same-viewport HTML/Flutter evidence; no automatic visual acceptance.
Requires Pillow, Playwright and local Chromium. Original reference stays intact.
"""
import argparse
import base64
import hashlib
import io
import json
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageStat
from playwright.sync_api import sync_playwright

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--repo',type=Path,default=Path(__file__).resolve().parents[1])
p.add_argument('--chromium',default='/usr/bin/chromium')
p.add_argument('--output',type=Path)
a=p.parse_args();repo=a.repo.resolve();output=a.output or repo/'docs/design/visual_closure_2026-10-30';output.mkdir(parents=True,exist_ok=True)
source=repo/'docs/design/reference_v2/SIRAJ_UIUX_REDESIGN_V2_INTERACTIVE.html'
font=repo/'assets/fonts/NotoSansArabic.ttf';goldens=repo/'test/goldens/reference_v2'
# Actual production composition uses no fake science/catalog. Synthetic cases
# explicitly use the real widgets with test-only contracts and isolated SQLite.
cases=[(n,n,{},None,False) for n in ['onboard','auth','home','chat','history','library','quiz','resources','settings']]
cases += [(f'onboard_{i+1}','onboard',{'onboard':i},None,False) for i in range(1,4)]
cases += [('login','auth',{'authLogin':True},None,False)]
cases += [(n,'settings',{},'delete' if n.startswith('delete') else 'logout',False) for n in ['logout','delete','delete_acknowledged']]
cases += [('chat_answer','chat',{'chatExample':True},None,True),('library_catalog','library',{},None,True),('quiz_setup','quiz',{},None,True),('quiz_mcq','quizRun',{'quizType':'mcq'},None,True),('quiz_trueFalse','quizRun',{'quizType':'tf'},None,True),('quiz_shortAnswer','quizRun',{'quizType':'written'},None,True),('quiz_review','quizReview',{},None,True),('quiz_result','result',{},None,True),('diagnostics','diagnostics',{'diagnosticResource':'rag','diagnosticIssue':'mismatch'},None,True)]
rows=[];geometry={}
with sync_playwright() as pw:
    browser=pw.chromium.launch(executable_path=a.chromium,headless=True,args=['--no-sandbox'])
    page=browser.new_page(device_scale_factor=1)
    page.route('**/*',lambda route:route.abort())
    page.set_content(source.read_text(),wait_until='domcontentloaded')
    encoded=base64.b64encode(font.read_bytes()).decode()
    page.add_style_tag(content="@font-face{font-family:'Noto Sans Arabic';src:url(data:font/ttf;base64,"+encoded+");font-weight:100 900}")
    page.evaluate('document.fonts.ready');initial=page.evaluate('JSON.stringify(state)')
    for width,height,browser_width,crop in [(380,737,1280,(8,34,388,771)),(370,683,390,(5,31,375,714))]:
        page.set_viewport_size({'width':browser_width,'height':1000})
        for dark in [False,True]:
            theme='dark' if dark else 'light'
            for name,route,overrides,modal,synthetic in cases:
                page.evaluate('(v)=>{Object.assign(state,JSON.parse(v.initial),v.overrides,{dark:v.dark});navigate(v.route);if(v.modal){openModal(v.modal);if(v.checked){state.modalChecked=true;render()}}}',{'initial':initial,'overrides':overrides,'dark':dark,'route':route,'modal':modal,'checked':name=='delete_acknowledged'})
                reference=Image.open(io.BytesIO(page.locator('.phone').screenshot())).convert('RGB').crop(crop)
                suffix='' if width==380 else '_370x683'
                actual_path=goldens/(f'state_ar_{theme}_{width}_{name}.png' if synthetic else f'app_ar_{theme}_{name}{suffix}.png')
                actual=Image.open(actual_path).convert('RGB')
                if reference.size!=actual.size or actual.size!=(width,height):raise ValueError(f'Viewport mismatch for {actual_path}')
                diff=ImageChops.difference(reference,actual)
                panel=Image.new('RGB',(width*3,height+32),'white')
                for x,im,label in [(0,reference,'Reference HTML'),(width,actual,'Actual Flutter'),(width*2,diff,'Absolute RGB difference')]:
                    panel.paste(im,(x,32));ImageDraw.Draw(panel).text((x+8,9),f'{name}/{theme} - {label}',fill='black')
                filename=f'{name}-{theme}-{width}x{height}-comparison.png';panel.save(output/filename)
                rows.append(dict(screen=name,theme=theme,viewport=f'{width}x{height}@1',mae_rgb_0_255=round(sum(ImageStat.Stat(diff).mean)/3,3),panel=filename,actual_sha256=hashlib.sha256(actual_path.read_bytes()).hexdigest(),test_fakes=synthetic,same_production_data=False,note='Descriptive metric; no approved pass threshold. Reference contains prototype data and controls excluded by P0.'))
                if not dark and name in ['onboard','home','settings','history','chat']:
                    geometry[f'{name}_{width}']=page.evaluate('''()=>{let b=document.querySelector('#appbar').getBoundingClientRect();return [...document.querySelectorAll('#appbar,#screen > *,#tabs,#tabs button,#screen .hero > *,#screen .onboard-halo,#screen .bookicon,#screen .steps,#screen .setting-row')].map(e=>{let r=e.getBoundingClientRect(),s=getComputedStyle(e);return{tag:e.tagName,cls:e.className,x:r.x-b.x,y:r.y-b.y,width:r.width,height:r.height,font:s.fontSize,line:s.lineHeight,weight:s.fontWeight}})}''')
    browser.close()
(output/'metrics.json').write_text(json.dumps({'reference_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'font_sha256':hashlib.sha256(font.read_bytes()).hexdigest(),'automatic_acceptance':False,'comparisons':rows},indent=2)+'\n')
(output/'reference-geometry.json').write_text(json.dumps(geometry,indent=2)+'\n')
print(f'{len(rows)} same-viewport comparison panels written; no automatic acceptance claimed.')

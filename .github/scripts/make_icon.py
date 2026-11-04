from PIL import Image, ImageDraw, ImageFont, ImageFilter
import sys
# Fonts: DM Serif Display (OFL), from github.com/google/fonts. Option 0 is the shipped icon.
F="fonts/"
def grad(N, top, bot, diag=True):
    g=Image.new("RGB",(N,N)); px=g.load()
    for y in range(N):
        for x in range(0,N,1):
            pass
    d=ImageDraw.Draw(g)
    for y in range(N):
        t=y/(N-1); d.line([(0,y),(N,y)],fill=tuple(int(top[i]*(1-t)+bot[i]*t) for i in range(3)))
    return g
def icon(font, size_frac, top, bot, ink, shadow=True, var=None, glow=None, dy=0.0, dx=0.0):
    N=1024*2
    img=grad(N, top, bot)
    if glow:  # soft warm highlight top-left
        hl=Image.new("L",(N,N),0); ImageDraw.Draw(hl).ellipse([-N*.3,-N*.4,N*.8,N*.6],fill=90)
        hl=hl.filter(ImageFilter.GaussianBlur(N*.12))
        img=Image.composite(Image.new("RGB",(N,N),glow),img,hl)
    f=ImageFont.truetype(F+font, int(N*size_frac))
    if var: f.set_variation_by_axes(var)
    layer=Image.new("L",(N,N),0); d=ImageDraw.Draw(layer)
    bbox=d.textbbox((0,0),"S",font=f)
    w,h=bbox[2]-bbox[0],bbox[3]-bbox[1]
    x=(N-w)/2-bbox[0]+dx*N; y=(N-h)/2-bbox[1]+dy*N
    d.text((x,y),"S",font=f,fill=255)
    if shadow:
        sh=layer.filter(ImageFilter.GaussianBlur(N*.018))
        sh=Image.eval(sh,lambda v:int(v*.35))
        off=Image.new("L",(N,N),0); off.paste(sh,(0,int(N*.014)))
        img=Image.composite(Image.new("RGB",(N,N),(60,20,10)),img,off)
    img=Image.composite(Image.new("RGB",(N,N),ink),img,layer)
    return img.resize((1024,1024),Image.LANCZOS)
def masked(img, s=256, bg=(250,248,244)):
    m=Image.new("L",(1024,1024),0); ImageDraw.Draw(m).rounded_rectangle([0,0,1023,1023],radius=230,fill=255)
    pv=Image.new("RGB",(1024,1024),bg); pv.paste(img,(0,0),m); return pv.resize((s,s),Image.LANCZOS)
if __name__=="__main__":
    cream=(253,244,230)
    opts=[
      icon("DMSerifDisplay-Regular.ttf",.78,(236,134,84),(190,72,48),cream,glow=(255,190,140)),
      icon("DMSerifDisplay-Italic.ttf",.80,(236,134,84),(190,72,48),cream,glow=(255,190,140)),
      icon("PlayfairDisplay-Italic[wght].ttf",.80,(244,170,92),(206,82,72),cream,var=[800],glow=(255,214,160)),
      icon("InstrumentSerif-Italic.ttf",.92,(214,108,62),(150,52,44),cream,glow=(250,170,110)),
    ]
    sheet=Image.new("RGB",(4*276+20,296),(250,248,244))
    for i,o in enumerate(opts):
        o.save(f"opt{i}.png"); sheet.paste(masked(o),(20+i*276,20))
    sheet.save("sheet.png")

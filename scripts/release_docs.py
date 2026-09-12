"""Build Chinese onboarding PDF and code-native installer artwork on macOS."""
from pathlib import Path
import argparse
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.colors import HexColor

p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args()
a.output.mkdir(parents=True,exist_ok=True)
root=Path(__file__).resolve().parents[1]
pdfmetrics.registerFont(TTFont('Song','/System/Library/Fonts/Supplemental/Songti.ttc',subfontIndex=6))
pdfmetrics.registerFont(TTFont('SongBold','/System/Library/Fonts/Supplemental/Songti.ttc',subfontIndex=1))
pdfmetrics.registerFont(TTFont('UI','/System/Library/Fonts/Supplemental/Arial Unicode.ttf'))
ink=HexColor('#203330');mint=HexColor('#55bda0');muted=HexColor('#57655f');orange=HexColor('#f16b2e')
manual=a.output/'JIAYU-Token-Float-0.1.0-Manual-zh-CN.pdf'
c=canvas.Canvas(str(manual),pagesize=(595,842));c.setTitle('JIAYU Token Float 0.1.0 中文使用说明书');c.setAuthor('JIAYU STUDIO')
def txt(x,y,t,size=12,font='Song',color=ink):
 c.setFillColor(color);c.setFont(font,size);c.drawString(x,842-y,t)
def lines(y,items):
 for line in items:txt(48,y,line);y+=22
 return y

def header(n,title,sub):
 c.setFillColor(HexColor('#f4f6f2'));c.rect(0,0,595,842,fill=1,stroke=0)
 c.drawImage(str(root/'Assets/logo.png'),48,748,width=54,height=54,mask='auto')
 txt(118,63,'JIAYU STUDIO',12,'Helvetica-Bold');txt(118,85,'TOKEN FLOAT  /  0.1.0',11,'Helvetica',muted)
 txt(48,145,title,27,'SongBold');txt(48,174,sub,11,'Song',muted)
 c.setStrokeColor(mint);c.line(48,645,547,645)
 txt(48,807,'JIAYU STUDIO · 用量悬浮窗',10,'Song',muted);txt(510,807,str(n)+' / 2',10,'Helvetica',muted)
header(1,'把每次运行，看得更清楚','macOS 13 及以上 · Apple Silicon（M 系列）· 中文快速上手')
txt(48,233,'01  安装：拖入「应用程序」',17,'SongBold')
lines(262,['打开 DMG，将应用拖入「应用程序」文件夹。','拷贝完成后，从「应用程序」打开 JIAYU Token Float 0.1.0。','最后弹出安装盘。更新已有安装时，请先退出正在运行的旧版本。'])
txt(48,358,'02  操作：拖动、展开、选择',17,'SongBold')
lines(388,['按住悬浮窗左侧四点拖动位置；再次启动会恢复保存的位置。','单击数值区域展开或收起，设置按钮位于展开面板的右上角。','「对话」查看单个任务；可自动跟随最近运行的主任务或手动锁定。','「分项目」按完整工作目录分组；「全部项目」汇总本机日志。'])
txt(48,506,'03  定制：只留下你想看的数值',17,'SongBold')
lines(536,['在设置中选择折叠时显示的第一项和第二项，设置会自动保存。','可选本轮、对话、项目、全部项目的 tokens，以及费用和速度。','可修改置顶状态、模型单价、人民币参考汇率和日志目录。','菜单栏图标可以重新显示悬浮窗、重置位置或退出程序。'])
c.setFillColor(HexColor('#e4eee7'));c.roundRect(48,106,499,68,12,fill=1,stroke=0)
txt(65,693,'首次打开可能需要几分钟扫描历史日志。',12,'SongBold')
txt(65,716,'扫描期间显示部分统计；完成后用本地数值缓存加速再次启动。',11)
c.showPage()
header(2,'读懂数字，也知道它的边界','速度与费用采用透明的估算口径；未知数据不会假装已经算全')
txt(48,233,'用量与速度',17,'SongBold')
lines(262,['tokens 总量 = 输入 + 输出。缓存输入已包含在输入中，','推理输出已包含在输出中，这两项不会再次叠加到总量。','输出均速 = 最近 60 秒日志记录的输出 tokens ÷ 60。','日志分批写入，因此这不是逐 token 的瞬时生成速度。'])
txt(48,374,'美元与人民币',17,'SongBold')
lines(404,['金额显示到 0.01。美元/分钟表示最近 60 秒已记录的等价费用。','金额是模型 tokens 的 API 等价估算，不是订阅扣费或账户账单，','不包括工具费用。缺少模型价格时，显示已知金额及「待计价」。','人民币默认使用手动参考汇率 7.0，不是实时汇率，可自行修改。'])
txt(48,517,'本地数据与常见问题',17,'SongBold')
lines(547,['只读本机可访问的会话及归档日志；未同步的远程任务无法统计。','本工具不联网、不读取钥匙串或认证文件，不需要录屏、辅助功能','或管理员权限。数值缓存不包含对话正文。','看不到窗口：点击菜单栏图标，选择重新显示或重置位置。','显示读取失败：在设置中重新选择可读取的 sessions 目录。'])
txt(48,692,'关于这个工具',13,'SongBold')
lines(717,['这是通过 AI 与人工协作完成的个人工具，用于备份、自用和社区分享。','自有代码与 ccusage 移植部分遵循 MIT；详见仓库许可声明。'])
txt(48,775,'本地 ad-hoc 签名；尚未获得 Apple 开发者公证。',10,'Song',muted)
c.save()
# Finder background: actual application/folder/document icons are placed by dmgbuild.
W,H=800,560
c=canvas.Canvas(str(a.output/'installer-background.pdf'),pagesize=(W,H))
def box(x,y,w,h,color,r=0):
 c.setFillColor(HexColor(color));c.roundRect(x,H-y-h,w,h,r,fill=1,stroke=0)
def t(x,y,s,size=14,color='#203330',font='UI',center=False):
 c.setFillColor(HexColor(color));c.setFont(font,size);(c.drawCentredString if center else c.drawString)(x,H-y,s)
box(0,0,W,H,'#f5f2eb');box(0,0,W,136,'#203330')
c.drawImage(str(root/'Assets/logo.png'),35,H-90,width=62,height=62,mask='auto')
t(114,48,'JIAYU STUDIO · TOKEN FLOAT',20,'#ffffff','Helvetica-Bold');t(114,72,'家宇工作室 · 用量悬浮窗 0.1.0',12,'#ddede5')
t(40,114,'拖进「应用程序」，把每次运行看清楚。',23,'#ffffff')
t(400,169,'给悬浮窗搬个家，拖一下就安装好了。',14,'#6f7771',center=True)
box(112,196,196,142,'#ffffff',24);box(492,196,196,142,'#ffe2c9',24)
t(210,218,'01  拎起左边的应用',12,'#6f7771',center=True);t(590,218,'02  放进右边文件夹',12,'#6f7771',center=True)
c.setStrokeColor(orange);c.setLineWidth(7);c.setLineCap(1);q=c.beginPath();q.moveTo(339,H-270);q.curveTo(370,H-245,425,H-245,458,H-270);c.drawPath(q)
q=c.beginPath();q.moveTo(444,H-247);q.lineTo(460,H-270);q.lineTo(433,H-270);c.drawPath(q)
t(400,312,'拖我过去',13,'#f16b2e',center=True)
t(400,383,'拷贝完成 → 从「应用程序」打开 → 推出安装盘',15,center=True)
box(30,403,740,1,'#deded4');t(48,439,'第一次使用？',17);t(48,465,'打开右侧中文说明书。',12,'#6f7771');t(48,488,'更新安装前，记得先退出旧版本。',11,'#6f7771')
t(48,537,'macOS 13+  /  Apple Silicon',10,'#6f7771','Helvetica');t(750,537,'0.1.0 · GUIDE',10,'#6f7771','Helvetica',True)
c.save();print(manual)

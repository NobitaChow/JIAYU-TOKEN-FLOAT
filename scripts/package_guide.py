"""Create the guided macOS installer. Requires dmgbuild 1.6.7."""
import argparse
from pathlib import Path
from dmgbuild import build_dmg
p = argparse.ArgumentParser()
for name in ('app', 'manual', 'background', 'output'):
    p.add_argument('--' + name, type=Path, required=True)
a = p.parse_args()
root = Path(__file__).resolve().parents[1]
build_dmg(str(a.output.resolve()), 'JIAYU Token Float 2.1.0', settings={
    'files': [str(a.app.resolve()), (str(a.manual.resolve()), '使用说明书.pdf'),
              (str(root / 'Docs/安装须知.txt'), '安装须知.txt')],
    'symlinks': {'Applications': '/Applications'},
    'background': str(a.background.resolve()),
    'icon': str(root / 'Assets/AppIcon.icns'),
    'window_rect': ((140, 80), (800, 650)),
    'icon_size': 88, 'text_size': 12, 'format': 'UDZO',
    'default_view': 'icon-view', 'show_status_bar': False,
    'show_toolbar': False, 'show_sidebar': False,
    'icon_locations': {a.app.name: (210, 275), 'Applications': (590, 275),
                       '使用说明书.pdf': (490, 461), '安装须知.txt': (660, 461)},
})

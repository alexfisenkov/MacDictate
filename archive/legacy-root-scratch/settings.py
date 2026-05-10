import os.path
import sys

# Определяем абс путь до папки build/dmg_src, где лежат MacDictate.app и Applications ярлык
application = 'build/dmg_src/MacDictate.app'
appname = 'MacDictate'

# Формат образа (UDZO — сжатый (стандарт Apple))
format = 'UDZO'

# Размер окна при монтировании образа
window_rect = ((100, 100), (600, 400))

# Картинка или вид фона
background = 'builtin-arrow'

# Иконка самого DMG-образа на рабочем столе
icon = 'assets/AppIcon.icns'

# Настройка иконок
files = [ application ]

# Прямая ссылка на программы
symlinks = { 'Applications': '/Applications' }

# Отключаем скрытые файлы .DS_Store, чтобы окно было чистым
hide_extension = []

# Расположение иконок в окне (X, Y)
# Слева - сама программа, справа - папка
icon_locations = {
    appname + '.app': (140, 190),
    'Applications': (460, 190)
}

# Подключаем EULA из нашего файла license.txt
with open('assets/license.txt', 'r', encoding='utf-8') as f:
    license_text = f.read()

license = {
    'default-language': 'ru_RU',
    'licenses': {
        'ru_RU': license_text
    }
}

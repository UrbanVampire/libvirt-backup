# libvirt-backup.sh - libvirt VMs backup script.
## English readme.
[:arrow_down:Инструкция на русском ниже.](https://github.com/UrbanVampire/libvirt-backup#%D1%80%D1%83%D1%81%D1%81%D0%BA%D0%B0%D1%8F-%D0%B8%D0%BD%D1%81%D1%82%D1%80%D1%83%D0%BA%D1%86%D0%B8%D1%8F)

## Features:

- simultaneous operation of several copies of the script with different settings on one host,
- "blacklist" to exclude some virtual machines from the backup process,
- individual disk backup settings for each virtual machine,
- backups archiving using 7zip, tar/gzip, tar/bzip2, pigz,
- flexible informing settings,
- logs output to STDIN, systemd journal, logfile,
- sending the results to e-mail or Telegram.

## Installation:

Download:
```
wget https://raw.githubusercontent.com/UrbanVampire/libvirt-backup/main/libvirt-backup.sh
```
make executable:
```
chmod +x libvirt-backup.sh
```
run:
```
./libvirt-backup.sh
```
## Usage:

At the first run the script will install required utilities.

NOTE: The following package managers are currently supported: apt-get, dnf, yum, zypper, pacman.
If you want to add support for another package manager - please contact the developer.

Also, when you run the script for the first time, it will create a configuration file that you will need to edit to suit your needs. The file contains comments explaining each parameter and specifying default values.

By default, the configuration file is created (and then searched for by the script) in the same folder as the script itself, with the same name and '.conf' extension. It is possible to store the configuration file in the '/etc' folder. To do this, you need to uncomment two lines in the script:

```
CONFIGFILE="/etc/$SCRIPTNAME.config"
if [ $EUID -ne 0 ]; then echo "Must be run with superuser privileges: sudo $OWNNAME"; exit 1; fi
```
The first line locates the config in '/etc', the second line checks for sudo privileges.

For your convenience, the script adds a complete list of your virtual machines and their disks to the configuration file. To generate an up-to-date list delete or rename the configuration file and run the script, a new configuration template with an up-to-date list will be generated.

If you want to use a script with different settings (e.g., archiving, storage location, or log method), create a copy of the script with a different name, and it will use its own settings file.

## Known issues:

The script does not support VM's names and paths with spaces.

##
In case you find a bug, inaccuracy, or have a suggestion to improve the script - please contact the developer.

# libvirt-backup.sh - Скрипт для резервного копирования виртуальных машин libvirt.
## Русская инструкция.
[:arrow_up:English readme is above.](https://github.com/UrbanVampire/libvirt-backup#english-readme)

## Возможности:

- одновременная работа нескольких копий скрипта с разными настройками на одном хосте,
- "чёрный список" для исключения части виртуальных машин из процесса резервного копирования,
- индивидуальные настройки резервного копирования дисков для каждой виртуальной машины,
- архивация резервных копий при помощи 7zip, tar/gzip, tar/bzip2, pigz,
- гибкие настройки информирования,
- вывод логов на STDIN, в журнал systemd, в файл,
- отправка результатов работы на e-mail или в Telegram.

## Установка:

Скачать:
```
wget https://raw.githubusercontent.com/UrbanVampire/libvirt-backup/main/libvirt-backup.sh
```
сделать исполняемым:
```
chmod +x libvirt-backup.sh
```
запустить:
```
./libvirt-backup.sh
```

## Использование:

При первом запуске скрипт установит необходимые для работы утилиты.

ВНИМАНИЕ! В данный момент поддерживаются следующие пакетные менеджеры: apt-get, dnf, yum, zypper, pacman.
Если вы хотите добавить поддержку другого пакетного менеджера - свяжитесь с разработчиком.

Также при первом запуске скрипт создаст файл конфигурации, который вам нужно будет отредактировать под свои нужды. Файл содержит комментарии с объяснением каждого параметра и указанием значений по-умолчанию.

По-умолчанию файл конфигурации создаётся (а затем ищется скриптом) в той же папке, в которой находится сам скрипт, и с тем же именем и расширением '.conf'. Имеется возможность хранения файла конфигурации в папке '/etc'. Для этого вам нужно раскомментировать две строки в теле скрипта:

```
CONFIGFILE="/etc/$SCRIPTNAME.config"
if [ $EUID -ne 0 ]; then echo "Must be run with superuser privileges: sudo $OWNNAME"; exit 1; fi
```
Первая строка определяет местоположение файла конфигурации в '/etc', вторая проверяет наличие прав sudo.

Для вашего удобства скрипт сразу добавляет в файл конфигурации полный список ваших виртуальных машин и их дисков. Чтобы сгенерировать актуальный список удалите или переименуйте файл конфигурации и запустите скрипт, будет сгенерирован новый шаблон конфигурации с актуальным списком.

Если вы хотите использовать скрипт с разными настройками (к примеру архивации, места хранения или метода информаирования), создайте копию скрипта с другим именем, и он будет использовать свой файл настроек.

## Известные проблемы:

Скрипт не поддерживает имена и пути виртуальных машин с пробелами.

##
В случае, если вы обнаружили ошибку, неточность, или имеете предложение по улучшению скрипта - свяжитесь с разработчиком.
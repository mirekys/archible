#!/bin/bash
#
# A Sensible Ansible Archlinux bootstrapping script
#
# by Mirek Bauer <mirekys@gmail.com>
# License: GNU GPLv3
#

AUR_HELPERS=("yay yay on", "aurman aurman off", "pacaur pacaur off", "trizen trizen off", "pikaur pikaur off")
LOGFILE='/tmp/archible_install.log'
echo '' > $LOGFILE

welcomeUser() {
    dialog --title "Welcome!" --yes-label "Like never before!" --no-label "Not yet..." \
	    --yesno "This script will automatically install a fully-featured i3wm Arch Linux \
	    desktop, based on Luke Smith's LARBS dotfiles, including some additional \
	    features.\\n\\nAre you ready??" 10 60 || { clear; exit -1; }
}

installPrereqs() {
    echo "</> Installing script prerequisites"
    pacman -S --noconfirm --needed base-devel >> $LOGFILE 2>&1 && echo "    - base-devel installed" || exit 1
    pacman -S --noconfirm --needed git >> $LOGFILE 2>&1 && echo "    - git installed" || exit 1
    pacman -S --noconfirm --needed dialog >> $LOGFILE 2>&1 && echo "    - dialog installed" || exit 1
}

preparePacman() {
    dialog --title "Prepare Pacman" --infobox "\\nRefreshing Arch Keyring..." 5 40
    pacman --noconfirm -Sy archlinux-keyring >/dev/null 2>&1
    dialog --title "Prepare Pacman" --infobox "\\nSynchronizing & updating packages..." 5 40
    pacman --noconfirm -Syyu >/dev/null 2>&1
}

installAnsible() {
    dialog --title "Prepare installation environment" --infobox "\\nInstalling and configuring Ansible..." 5 70
    pacman -S --noconfirm --needed ansible >> $LOGFILE 2>&1 || exit 1
}

installAnsibleDeps() {
    dialog --title "Prepare installation environment" --infobox "\\nInstalling Ansible Galaxy dependencies..." 5 70 &&
    ansible-galaxy install -r requirements.yml >> $LOGFILE 2>&1
    dialog --title "Prepare installation environment" --infobox "\\nInstalling python-passlib..." 5 70 &&
    pacman -S --noconfirm --needed python-passlib >> $LOGFILE 2>&1 || exit 1
}

installGitPlugin() {
    plugDir=$(dirname $plugin)
    destDir="${HOME}/.ansible/${plugDir#"./3rdparty/"}"

    [ ! -d "$destDir" ] && mkdir -p $destDir

    while read -r name source; do
        [ -d "${destDir}/${name}" ] && continue  # TODO: pull latest master changes
        dialog --title "Prepare installation environment" --infobox "\\nInstalling \"$name\" from \"$source\"..." 5 70
        git clone "$source" "${destDir}/${name}" >> $LOGFILE 2>&1 || dialog --title "Error" --infobox "\\nFailed to install $name" 5 70 && sleep 5
    done < $plugin
}

install3rdPartyPlugins() {
    dialog --title "Prepare installation environment" --infobox "\\nInstalling 3rd party Ansible dependencies..." 5 70 && sleep 1
    for plugin in $(find ./3rdparty/ -name '*.lst'); do
        case $(basename ${plugin%.*}) in
            git) installGitPlugin ;;
            *) dialog --title "Error" --infobox "Unsupported plugin type $(basename ${plugin%.*})" 5 70 && sleep 5
        esac
    done
}

setupAnsiblePreferences() {
    echo '---' > preferences.yml && clear
    tz=$(tzselect) && clear
    username=$(dialog --inputbox "What is your haxxor username?" 8 60 3>&1 1>&2 2>&3 3>&1) || exit
    hostname=$(dialog --inputbox "What is your l33t machine's name?" 8 60 $(hostname) 3>&1 1>&2 2>&3 3>&1) || exit
    # TODO: figure out how to parse wildly formatted locale.gen file
    #localeSupport=$(dialog --checklist "Choose supported locales:" 80 40 30 $(sed '/^# .*/d' /etc/locale.gen | sed '/^#$/d' | sed 's/ *$//' | sed 's/ /./' | awk -F'#' '{print NR-1" "$2" "$2}')
    # NOW we just do a default en_US.UTF-8 locale (LARBS dotfiles support only this anyway)
    localeSupport=('en_US.UTF-8')
    localeLANG=$(dialog --no-tags --radiolist "Choose your primary locale:" 80 40 30 \
	    $(for l in ${localeSupport[@]}; do echo "$l $l off"; done) 3>&1 1>&2 2>&3 3>&1) || exit
    aurHelper=$(dialog --no-tags --radiolist "What is your favorite AUR helper?" 15 40 40 \
        $(for h in ${AUR_HELPERS[@]}; do echo "$h"; done) 3>&1 1>&2 2>&3 3>&1)

    cat > preferences.yml <<EOL
---
ntp_timezone: ${tz}
user_name: ${username}
host_name: ${hostname}
locale_locales: ${localeSupport}
locale_primary: ${localeLANG}
aur_helper: ${aurHelper}
EOL
}

prepareEnvironment() {
    installAnsible || exit 1
    installAnsibleDeps || exit 2
    install3rdPartyPlugins || exit 3
    setupAnsiblePreferences
}

launchAnsiblePlaybook() {
    dialog --title "READY!" --yes-label 'Oh YES!' --no-label 'Oh NOO!' \
	    --yesno "Everything is now ready to go!. The next steps WILL overwrite your dotfiles \
	    and modify your system configuration.\\n\\nThere is no coming back beyond this point!\\n\\n\\n \
	    Do you still want to do this??" 13 60 && clear || { clear; exit 10; }
    ansible-playbook -i inventory.yml playbook.yml
}

cleanup() {
    dialog --title "Polishing" --infobox "\\nCleaning up the installation..." 5 70 && sleep 2
    clear
    # TODO: do an actual cleanup of ansible packages
}

# Check for root user
if [ $(id -u) -ne 0 ]; then
    echo "<E> You must be root to run this script."
    exit -1
fi

# Check for network connectivity
if ! ping -c 3 archlinux.org >> $LOGFILE 2>&1; then
    echo "<E> You must have network connectivity before running this script."
    exit -1
fi

installPrereqs || exit -1
welcomeUser
preparePacman
prepareEnvironment
launchAnsiblePlaybook
cleanup


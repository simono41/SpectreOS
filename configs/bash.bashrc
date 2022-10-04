#
# /etc/bash.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

[[ $DISPLAY ]] && shopt -s checkwinsize

PS1='[\u@\h \W]\$ '

case ${TERM} in
  xterm*|rxvt*|Eterm|aterm|kterm|gnome*)
    PROMPT_COMMAND=${PROMPT_COMMAND:+$PROMPT_COMMAND; }'printf "\033]0;%s@%s:%s\007" "${USER}" "${HOSTNAME%%.*}" "${PWD/#$HOME/\~}"'

    ;;
  screen*)
    PROMPT_COMMAND=${PROMPT_COMMAND:+$PROMPT_COMMAND; }'printf "\033_%s@%s:%s\033\\" "${USER}" "${HOSTNAME%%.*}" "${PWD/#$HOME/\~}"'
    ;;
esac

[ -r /usr/share/bash-completion/bash_completion   ] && . /usr/share/bash-completion/bash_completion

echo -e "\n";
echo -e "\033[1;33m Willkommen auf $(uname -n) \033[0m";
echo -e "\n";
echo -e "=============================================================================================="
echo -e "\033[1;33m Systemzeit:      \033[0m" `date | awk '{print $4}'`
echo -e "\033[1;33m Online seit:     \033[0m" `uptime | awk '{print $3}'` "Stunden"
echo -e "\033[1;33m Speichernutzung: \033[0m" `cat /proc/meminfo|grep 'MemF'| awk '{print $2}'` "kB von" `cat /proc/meminfo|grep 'MemT'| awk '{print $2}'` "kB frei"
if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
echo -e "\033[1;33m CPU-Temp:        \033[0m" `cat /sys/class/thermal/thermal_zone0/temp| awk '{print $1/1000}'` "°C"
fi
echo -e "\033[1;33m IPs:             \033[0m" `ip addr | grep 'inet' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -o -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1`
echo -e "\033[1;33m Macs:            \033[0m" `ip link | grep ether`
echo -e "\033[1;33m Benutzer:        \033[0m" `whoami`
echo -e "\033[1;33m Grafikkarte:     \033[0m" `lspci | grep -e VGA -e 3D -m 1`
#echo -e "\033[1;33m OpenGL renderer: \033[0m" `glxinfo | grep "OpenGL renderer"`
#echo -e "\033[1;33m Öffentliche IP:  \033[0m" `wget -qO- ipv6.icanhazip.com || echo "Gescheitert"`
echo -e "=============================================================================================="
echo -e "User     Anschluß     Seit              von"
/usr/bin/who
echo -e "=============================================================================================="

alias reboot="sudo systemctl reboot"
alias poweroff="sudo systemctl poweroff"
alias halt="sudo systemctl halt"
alias hibernate="sudo systemctl hibernate"
alias hybrid="sudo systemctl hybrid-sleep"
alias suspend="sudo systemctl suspend"

eval "$(starship init bash)"

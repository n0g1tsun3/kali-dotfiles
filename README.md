# kali-dotfiles

## Update
```bash
echo "deb http://http.kali.org/kali kali-rolling main contrib non-free non-free-firmware" | sudo tee /etc/apt/sources.list
sudo apt update && sudo apt -y full-upgrade
cp -vrbi /etc/skel/. ~/
[ -f /var/run/reboot-required ] && sudo reboot -f
```

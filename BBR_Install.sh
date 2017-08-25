#!/bin/bash

function Colorset() {
  #颜色配置
  echo=echo
  for cmd in echo /bin/echo; do
    $cmd >/dev/null 2>&1 || continue
    if ! $cmd -e "" | grep -qE '^-e'; then
      echo=$cmd
      break
    fi
  done
  CSI=$($echo -e "\033[")
  CEND="${CSI}0m"
  CDGREEN="${CSI}32m"
  CRED="${CSI}1;31m"
  CGREEN="${CSI}1;32m"
  CYELLOW="${CSI}1;33m"
  CBLUE="${CSI}1;34m"
  CMAGENTA="${CSI}1;35m"
  CCYAN="${CSI}1;36m"
  CSUCCESS="$CDGREEN"
  CFAILURE="$CRED"
  CQUESTION="$CMAGENTA"
  CWARNING="$CYELLOW"
  CMSG="$CCYAN"
}

function Logprefix() {
  #输出log
  echo -n ${CGREEN}'CraftYun >> '
}

function Checksystem() {
  cd
  Logprefix;echo ${CMSG}'[Info]检查系统'${CEND}
  #检查系统
  if [[ $(id -u) != '0' ]]; then
    Logprefix;echo ${CWARNING}'[Error]请使用root用户安装!'${CEND}
    exit
  fi

  if grep -Eqii "CentOS" /etc/issue || grep -Eq "CentOS" /etc/*-release; then
    DISTRO='CentOS'
  else
    DISTRO='unknow'
  fi

  if [[ ${DISTRO} == 'unknow' ]]; then
    Logprefix;echo ${CWARNING}'[Error]请使用Centos系统安装!'${CEND}
    exit
  fi

  if grep -Eqi "release 5." /etc/redhat-release; then
      RHEL_Version='5'
  elif grep -Eqi "release 6." /etc/redhat-release; then
      RHEL_Version='6'
  elif grep -Eqi "release 7." /etc/redhat-release; then
      RHEL_Version='7'
  fi

  if [[ ${RHEL_Version} != '7' ]]; then
    Logprefix;echo ${CWARNING}'[Error]请使用Centos7安装!'${CEND}
    exit
  fi

  if [[ `getconf WORD_BIT` = '32' && `getconf LONG_BIT` = '64' ]] ; then
      OS_Bit='64'
  else
      OS_Bit='32'
  fi

  if [[ ${OS_Bit} == '32' ]]; then
    Logprefix;echo ${CWARNING}'[Error]请使用64位Centos7!'${CEND}
    exit
  fi
}

function Coloseselinux() {
  #关闭selinux
  Logprefix;echo ${CMSG}'[Info]关闭Selinux'${CEND}
  [ -s /etc/selinux/config ] && sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
	setenforce 0 >/dev/null 2>&1
}

function Yumupdate() {
  #升级系统软件
  Logprefix;echo ${CMSG}'[Info]升级系统软件,可能需要花费较长时间，请耐心等待'${CEND}
  yum -y update
}

function Installbasesoftware() {
  #安装基础软件
  Logprefix;echo ${CMSG}'[Info]安装基础软件'${CEND}
  Logprefix;echo ${CMSG}'[Info]安装epel源'${CEND}
  yum -y install epel-release
  Logprefix;echo ${CMSG}'[Info]安装wget'${CEND}
  yum -y install wget
  Logprefix;echo ${CMSG}'[Info]安装lrzsz'${CEND}
  yum -y install lrzsz
  Logprefix;echo ${CMSG}'[Info]安装zip unzip'${CEND}
  yum -y install unzip zip
  Logprefix;echo ${CMSG}'[Info]安装Development Tools'${CEND}
  yum -y groupinstall "Development Tools"
}

function Askuser() {
  OPTION=$(whiptail --clear --nocancel --menu "请选择选项" 15 60 4 \
"1" "升级系统内核" \
"2" "安装原版BBR(请确认已升级内核)" \
"3" "安装魔改版BBR(请确认已升级内核)" \
"4" "取消安装" \
3>&1 1>&2 2>&3)
  Logprefix;echo ${CMSG}'[Info]提示:按下回车键开始，或使用CTRL+C退出'${CEND}
  read
  case ${OPTION} in
  1)
    InstallKernel
    ;;
  2)
    InstallBBR
    ;;
  3)
    InstallBBR_tsunami
    ;;
  4)
    exit
    ;;
  esac
}

function Installok() {
  #安装完成提示
  Logprefix;echo ${CMAGENTA}'[Success]安装完成'${CEND}
}

function InstallKernel() {
  # 安装内核
  Logprefix;echo ${CMSG}'[Info]安装kernel'${CEND}
  rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
  rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm
  # 安装内核
  yum -y remove kernel-headers
  yum -y --enablerepo=elrepo-kernel install kernel-ml kernel-ml-headers kernel-ml-devel
  # 设置启动顺序
  grub2-set-default 0
  Logprefix;echo ${CMAGENTA}'[Success]安装完成,按下回车键重启'${CEND}
  read
  reboot
}

function InstallBBR() {
  echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
  echo "net.ipv4.tcp_congestion_control = bbr" >> /etc/sysctl.conf
  sysctl -p
  lsmod | grep bbr
  Logprefix;echo ${CMAGENTA}'[Success]安装完成'${CEND}
}

function InstallBBR_tsunami() {
  yum install -y make gcc wget
  wget -O ./tcp_tsunami.c https://gist.github.com/anonymous/ba338038e799eafbba173215153a7f3a/raw/55ff1e45c97b46f12261e07ca07633a9922ad55d/tcp_tsunami.c
  echo "obj-m:=tcp_tsunami.o" > Makefile
  make -C /lib/modules/$(uname -r)/build M=`pwd` modules CC=/usr/bin/gcc
  chmod +x ./tcp_tsunami.ko
  cp -rf ./tcp_tsunami.ko /lib/modules/$(uname -r)/kernel/net/ipv4
  insmod tcp_tsunami.ko
  depmod -a
  echo "net.core.default_qdisc = fq" >> /etc/sysctl.conf
  echo "net.ipv4.tcp_congestion_control = tsunami" >> /etc/sysctl.conf
  sysctl -p
  lsmod | grep tsunami
  Logprefix;echo ${CMAGENTA}'[Success]安装完成'${CEND}
}

Colorset
Checksystem

Coloseselinux
Installbasesoftware
Yumupdate

#安装开始
Askuser
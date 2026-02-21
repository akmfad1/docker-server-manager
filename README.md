<div dir="rtl">

# 🐳 Docker Server Manager

یک منوی تعاملی قدرتمند به زبان Bash برای مدیریت سرویس‌های Docker، مانیتورینگ سیستم، فایروال، SSH، کرون‌جاب و بیشتر — همه از یک رابط ترمینالی.

> **طراحی‌شده برای سرورهای Ubuntu/Debian با Docker Compose**

---

## ✨ امکانات

| دسته‌بندی | قابلیت‌ها |
|-----------|-----------|
| 🐳 **پروژه‌های Docker** | Up / Down / Restart / Logs / Exec / Pull / Auto-Update برای هر پروژه |
| 📊 **مانیتورینگ** | htop، حافظه، پورت‌ها، رویدادهای Docker، CrowdSec، لاگین‌های ناموفق SSH |
| 🌐 **شبکه** | بررسی شبکه‌های Docker، iptables، مسیرهای هاست |
| ⚙️ **سیستم** | دیسک، پاکسازی، apt update، ری‌استارت، بکاپ فایل‌های compose |
| 🔥 **فایروال (UFW)** | فعال/غیرفعال، Allow/Deny پورت با توضیحات، حذف قوانین |
| 🔒 **تنظیمات SSH** | ویزارد تغییر پورت/تایم‌اوت با امکان بازگشت ایمن |
| ⏱️ **مدیریت Crontab** | ویزارد گام‌به‌گام، نمایش، حذف، ویرایش |
| 🖥️ **تنظیمات سیستم** | منطقه زمانی (تهران)، تغییر hostname |
| 🔄 **بروزرسانی خودکار** | آپدیت مستقیم از GitHub |

---

## 📦 نصب

### نصب یک‌خطی (پیشنهادی)

</div>

```bash
curl -fsSL https://raw.githubusercontent.com/akmfad1/docker-server-manager/main/install.sh | bash
```

<div dir="rtl">

### نصب دستی

</div>

```bash
curl -fsSL https://raw.githubusercontent.com/akmfad1/docker-server-manager/main/dockermenu.sh \
  -o /usr/local/bin/dockermenu
chmod +x /usr/local/bin/dockermenu
```

<div dir="rtl">

---

## 🚀 اولین اجرا

در اولین راه‌اندازی، یک ویزارد از شما مسیر پروژه‌های Docker را می‌پرسد:

</div>

```
=====================================
  Docker Server Manager - First Run
=====================================

Enter your Docker projects base directory [/root/docker-services]:
```

<div dir="rtl">

پیکربندی در مسیر `~/.config/dockermenu/config` ذخیره می‌شود و در هر بار اجرا بارگذاری می‌گردد.

---

## 📁 ساختار دایرکتوری

مسیر BASE_DIR باید شامل یک پوشه به ازای هر پروژه با فایل `docker-compose.yml` باشد:

</div>

```
/root/docker-services/
├── nginx-proxy/
│   └── docker-compose.yml
├── nextjs-app/
│   └── docker-compose.yml
└── monitoring/
    └── docker-compose.yml
```

<div dir="rtl">

هر پروژه به صورت خودکار به عنوان یک گزینه در منوی اصلی نمایش داده می‌شود.

---

## 🗂️ نمای کلی منو

</div>

```
Docker Server Manager
---------------------------------
1) nginx-proxy
2) nextjs-app
3) monitoring
4) Monitoring
5) Network Menu
6) System Menu
7) Firewall
8) SSH Config
9) System Settings
10) Exit
```

<div dir="rtl">

### منوی پروژه (برای هر پروژه)

</div>

```
1)  Up (no build)
2)  Up (with build)
3)  Down                    ← نیاز به تأیید دارد
4)  Restart all services    ← نیاز به تأیید دارد
5)  Restart single service
6)  Logs (select service)
7)  Logs all services (tail 100)
8)  Exec bash (select service)
9)  Env variables (select service)
10) Status
11) Pull
12) Validate config
13) Auto Update Stack (Pull + Up + Prune)
14) Back
```

<div dir="rtl">

### منوی مانیتورینگ

</div>

```
1)  htop
2)  uptime
3)  Memory (free -m)
4)  Open ports (ss -tulpn)
5)  Docker journal (live)
6)  UFW status
7)  CrowdSec metrics       ← در صورت نبود، نصب پیشنهاد می‌دهد
8)  CrowdSec decisions     ← در صورت نبود، نصب پیشنهاد می‌دهد
9)  Docker events (last 1h)
10) Top memory processes
11) Disk I/O (iostat)
12) Last logins
13) Failed SSH logins (today)
```

<div dir="rtl">

### منوی فایروال (UFW)

</div>

```
1) Show full rules
2) Enable UFW
3) Disable UFW             ← نیاز به تأیید دارد
4) Allow a port/service    ← پورت + توضیحات می‌پرسد
5) Deny a port/service     ← پورت + توضیحات می‌پرسد
6) Delete a rule           ← ابتدا لیست شماره‌دار نمایش می‌دهد
```

<div dir="rtl">

### ویزارد SSH

تغییر تنظیمات SSH با بکاپ خودکار و امکان بازگشت:

</div>

```
Port            [22]
MaxAuthTries    [3]
LoginGraceTime  [20]
MaxSessions     [5]
```

<div dir="rtl">

- قبل از اعمال، فایل `/etc/ssh/sshd_config` بکاپ می‌گیرد
- تست سینتکس با `sshd -t` انجام می‌شود
- از شما می‌خواهد از ترمینال دیگری اتصال SSH را تأیید کنید
- در صورت عدم تأیید، به طور خودکار تنظیمات قبلی بازگردانده می‌شود

### مدیریت Crontab

</div>

```
1) List all cron jobs
2) Add new cron job (wizard)
3) Delete a cron job by line number
4) Edit crontab directly (nano)
```

<div dir="rtl">

نمونه پیش‌نمایش ویزارد:

</div>

```
--- Preview ---
# پاکسازی روزانه Docker در ساعت 3 صبح
0 3 * * * docker image prune -f
----------------
Add this cron job? (y/N):
```

<div dir="rtl">

### تنظیمات سیستم

</div>

```
1) Set timezone to Asia/Tehran
2) Set custom timezone
3) Change hostname
4) Show full system info
```

<div dir="rtl">

---

## 🔄 بروزرسانی

### از داخل برنامه
**System Menu ← گزینه ۱۴ ← Update dockermenu**

### بروزرسانی دستی

</div>

```bash
curl -fsSL https://raw.githubusercontent.com/akmfad1/docker-server-manager/main/install.sh | bash
```

<div dir="rtl">

---

## 📋 پیش‌نیازها

| مورد | توضیح |
|------|-------|
| سیستم‌عامل | Ubuntu 20.04+ / Debian 11+ |
| Bash | نسخه 4.0+ |
| Docker | در صورت نبود، نصب خودکار پیشنهاد می‌شود |
| Docker Compose | نسخه V2 (دستور `docker compose`) |
| sudo | برای عملیات سیستمی |
| curl | برای بروزرسانی خودکار |

### اختیاری
- `htop` — نمایش پروسه‌ها
- `ufw` — مدیریت فایروال
- `crowdsec` + `crowdsec-firewall-bouncer-iptables` — جلوگیری از نفوذ (در صورت نبود، نصب پیشنهاد می‌شود)
- `sysstat` (`iostat`) — مانیتورینگ I/O دیسک

---

## ⚙️ پیکربندی

مسیر فایل تنظیمات: `~/.config/dockermenu/config`

</div>

```bash
BASE_DIR="/root/docker-services"
```

<div dir="rtl">

برای تنظیم مجدد، فایل config را حذف و برنامه را مجدداً اجرا کنید:

</div>

```bash
rm ~/.config/dockermenu/config
dockermenu
```

<div dir="rtl">

---

## 📝 لاگ‌ها

تمام عملیات در `/var/log/dockermenu.log` ثبت می‌شود:

</div>

```
2026-02-21 14:32:01 - nginx-proxy - up
2026-02-21 14:45:11 - nextjs-app - auto update
2026-02-21 15:00:00 - SSH config changed - Port:2222 MaxAuthTries:3 LoginGraceTime:20 MaxSessions:5
```

<div dir="rtl">

---

## 🔧 توسعه و مشارکت

</div>

```bash
git clone https://github.com/akmfad1/docker-server-manager.git
cd docker-server-manager
chmod +x dockermenu.sh install.sh
./dockermenu.sh
```

<div dir="rtl">

---

## 📄 لایسنس

MIT License — استفاده و تغییر آزاد است.

---

<p align="center">
ساخته‌شده با ❤️ برای مدیریت آسان سرورهای لینوکس
<br><br>
<a href="https://github.com/akmfad1/docker-server-manager">github.com/akmfad1/docker-server-manager</a>
</p>

</div>
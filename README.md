<div dir="rtl">

# 🐳 Docker Server Manager

یک منوی تعاملی قدرتمند به زبان Bash برای مدیریت سرویس‌های Docker، مانیتورینگ سیستم، فایروال، SSH، کرون‌جاب و بیشتر — همه از یک رابط ترمینالی.

> **طراحی‌شده برای سرورهای Ubuntu/Debian با Docker Compose**

---

## ✨ امکانات

| دسته‌بندی | قابلیت‌ها |
|-----------|-----------|
| 🐳 **پروژه‌های Docker** | Up / Down / Restart / Logs / Exec / Pull / Auto-Update برای هر پروژه |
| 📊 **مانیتورینگ** | htop، حافظه، پورت‌ها، رویدادهای Docker، CrowdSec، لاگین‌های ناموفق SSH، Health Check کانتینرها |
| 🌐 **شبکه** | بررسی شبکه‌های Docker، iptables، مسیرهای هاست |
| ⚙️ **سیستم** | دیسک، پاکسازی، apt update، ری‌استارت، بکاپ فایل‌های compose |
| 🔥 **فایروال (UFW)** | فعال/غیرفعال، Allow/Deny پورت با توضیحات، حذف قوانین |
| 🛡️ **Fail2Ban** | مشاهده IP‌های بن‌شده، Unban، آمار جیل‌ها |
| 💾 **بکاپ و لاگ** | بکاپ Docker Volumes، بکاپ دیتابیس (PG/MySQL/Mongo)، مدیریت و پاکسازی لاگ‌های Docker |
| 📈 **منابع** | مصرف زنده CPU/MEM، کانتینرهای بدون محدودیت حافظه، تاریخچه OOM Kill |
| 🔒 **امنیت** | آدیت امنیتی کانتینرها، کانتینرهای Privileged، پورت‌های عمومی، اسکن Trivy |
| �🔒 **تنظیمات SSH** | ویزارد تغییر پورت/تایم‌اوت با امکان بازگشت ایمن |
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
Repository: https://github.com/akmfad1/docker-server-manager
Version: 1.0.3

1) nginx-proxy
2) nextjs-app
3) monitoring
4) Monitoring
5) Docker Management
6) Network Menu
7) System Menu
8) Firewall
9) SSH Config
10) System Settings
11) Exit
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
3)  Memory (free -h)
4)  Open ports (ss -tulpn)
5)  Docker journal (live)
6)  UFW status
7)  CrowdSec metrics       ← در صورت نبود، نصب پیشنهاد می‌دهد
8)  CrowdSec decisions     ← در صورت نبود، نصب پیشنهاد می‌دهد
9)  CrowdSec - Apply ArvanCloud Whitelist ← راه‌اندازی خودکار whitelist آروان
10) Docker events (last 1h)
11) Top memory processes
12) Disk I/O (iostat)
13) Last logins
14) Failed SSH logins (today)
15) Health check all services     ← وضعیت کلی + کانتینرهای مشکل‌دار
16) Security audit                ← آدیت امنیتی: Privileged، root، پورت‌های عمومی
```

<div dir="rtl">

### منوی Docker Management

مدیریت جهانی تمام سرویس‌های Docker:

</div>

```
1) Docker stats (live)              ← مانیتورینگ زنده منابع
2) Docker stats (snapshot)          ← عکس‌فوری از وضعیت فعلی
3) Docker system df                ← مصرف فضای Docker
4) Restart Docker service          ← ری‌استارت daemon
5) Prune stopped containers        ← پاک‌سازی کانتینرهای متوقف
6) Prune unused volumes            ← پاک‌سازی حجم‌های سالم
7) Prune unused networks           ← پاک‌سازی شبکه‌های استفاده‌نشده
8) Full Docker system prune        ← پاک‌سازی کامل (⚠️ دقت لازم)
9) Backup Docker volumes           ← بکاپ حجم‌های Docker
10) Manage Docker logs             ← مدیریت و پاکسازی لاگ‌ها
11) Resource limits & usage        ← مصرف منابع و کانتینرهای بدون محدودیت
12) Database backup                ← بکاپ Postgres/MySQL/MariaDB/MongoDB
```

<div dir="rtl">

### منوی Network

مدیریت شبکه‌های Docker و فایروال سطح هاست:

</div>

```
1) List Docker networks         ← نمایش تمام شبکه‌های Docker
2) Inspect a network           ← مشخصات کامل یک شبکه
3) List containers in a network ← کانتینرهایی که به شبکه متصل‌اند
4) Remove unused networks      ← حذف شبکه‌های سالم
5) Show host routes            ← مسیرهای یا آپی سرور
6) Show iptables rules         ← قوانین فایروال درونی
```

<div dir="rtl">

### منوی System

#### گزینه‌های اصلی:

</div>

```
1) Disk usage (df -h)          ← مصرف دیسک
2) Update system (apt)         ← بروزرسانی سیستم
3) Failed systemd services    ← سرویس‌های خاموش‌شده
4) Cron jobs                   ← مدیریت Crontab
5) Backup compose files        ← بکاپ دایرکتوری پروژه‌ها
6) Package installer           ← نصب بسته‌های مختلف
7) Reboot system               ← ری‌استارت سرور
8) Update dockermenu           ← بروزرسانی اسکریپت
```

<div dir="rtl">

#### منوی Package Installer (زیرمنو):

</div>

```
1) Essential bundle            ← تمام ابزار پایه یکجا
   (htop, ncdu, iotop, nethogs, vnstat, nmap و غیره)

2) Network tools               ← htop, nethogs, vnstat, nmap, net-tools, dnsutils
3) General tools               ← curl, wget, git, nano, vim, unzip, zip, tree, jq, rsync, sysstat
4) Security tools              ← fail2ban, ufw, certbot
5) Terminal tools              ← tmux, ncdu, iotop
6) Install custom package      ← نصب بسته دلخواه
7) Show installed status       ← وضعیت نصب تمام بسته‌ها
```

<div dir="rtl">

### منوی SSH Config

تنظیمات و مدیریت SSH:

</div>

```
1) View current SSH config     ← نمایش تنظیمات فعلی
2) Change SSH settings (wizard) ← ویزارد تغییر تنظیمات (با بکاپ خودکار)
3) Test SSH config syntax (sshd -t) ← بررسی صحت‌تنظیمات
4) Restart SSH service         ← ری‌استارت درشیون SSH
5) Show active SSH listeners   ← پورت‌های فعلاً در حال‌گوش‌دادن
```

<div dir="rtl">

#### ویزارد تغییر SSH:

تغییر تنظیمات SSH با بکاپ خودکار و امکان بازگشت:

</div>

```
Port            [22]
MaxAuthTries    [3]
LoginGraceTime  [20]
MaxSessions     [5]
```

<div dir="rtl">

**ویژگی‌های ویزارد:**
- قبل از اعمال، فایل `/etc/ssh/sshd_config` بکاپ می‌گیرد
- تست سینتکس با `sshd -t` انجام می‌شود
- از شما می‌خواهد از ترمینال دیگری اتصال SSH را تأیید کنید
- در صورت عدم تأیید، به طور خودکار تنظیمات قبلی بازگردانده می‌شود

### منوی فایروال (UFW)

</div>

```
1) Show full rules
2) Enable UFW
3) Disable UFW             ← نیاز به تأیید دارد
4) Allow a port/service    ← پورت + توضیحات می‌پرسد
5) Deny a port/service     ← پورت + توضیحات می‌پرسد
6) Delete a rule           ← ابتدا لیست شماره‌دار نمایش می‌دهد
7) Fail2Ban Management     ← مدیریت Fail2Ban و بن‌شدگان
```

<div dir="rtl">

#### منوی Fail2Ban

مدیریت Fail2Ban برای امنیت بهتر:

</div>

```
1) Show banned IPs (SSH)            ← نمایش IP‌های بن شده در جیل SSH
2) Show banned IPs (all jails)      ← تمام جیل‌ها و IP‌های بن
3) Unban a specific IP              ← خروج IP از جیل
4) View fail2ban status             ← وضعیت سرویس و جیل‌های فعال
5) Show jail statistics             ← آمار failed و banned برای هر جیل
```

<div dir="rtl">

### منوی Crontab Manager

مدیریت کار‌های برنامه‌ریزی‌شده:

</div>

```
1) List all cron jobs
2) Add new cron job (wizard)       ← ویزارد گام‌به‌گام
3) Delete a cron job by line number
4) Edit crontab directly (nano)
```

<div dir="rtl">

نمونه پیش‌نمایش ویزارد:

</div>

```
Step 5/6 - Day/Week (0=Sun, 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat) [*]:
--- Preview ---
# پاکسازی روزانه Docker در ساعت 3 صبح
0 3 * * * docker image prune -f
----------------
Add this cron job? (y/N):
```

<div dir="rtl">

---

## ⌨️ میانبرهای صفحه‌کلید

تمامی منوها از میانبرهای زیر پشتیبانی می‌کنند:

| کلید | عملکرد |
|------|--------|
| `b` یا `B` | برگشت به منوی قبلی |
| `e` یا `E` | خروج از برنامه |

---

### منوی System Settings

تنظیمات کلی سیستم:

</div>

```
1) Set timezone to Asia/Tehran ← تنظیم منطقه زمانی ایران
2) Set custom timezone         ← تنظیم منطقه زمانی دلخواه
3) Change hostname             ← تغییر نام دستگاه
4) DNS Management              ← مدیریت DNS
5) Network Testing             ← تست کنندگی شبکه
6) Show full system info       ← نمایش اطلاعات جامع سیستم
```

<div dir="rtl">

#### مدیریت DNS

تنظیم سریع DNS با چندین پریست:

</div>

```
1) Custom DNS (دریافت از کاربر)  ← ورود دستی DNS‌های دلخواه
2) Public DNS (عمومی)           ← Google & Cloudflare
   DNS=8.8.8.8 1.1.1.1
   FallbackDNS=9.9.9.9
3) Shecan (شکن)                ← برای دسترسی به محتوای فیلترشده
   DNS=178.22.122.100 185.51.200.2
   FallbackDNS=8.8.8.8
4) Infrastructure (زیرساخت)    ← DNS ایرانی
   DNS=217.218.127.127 217.218.155.155
   FallbackDNS=8.8.8.8
5) Reset to Default (DHCP)     ← بازنشانی به تنظیمات پیش‌فرض
```

<div dir="rtl">

#### تست شبکه

ابزارهای تشخیصی شبکه:

</div>

```
1) Ping google.com (4 packets)        ← تست اتصال
2) DNS Lookup google.com              ← جستجوی DNS
3) DNS Lookup (current resolver)      ← جستجو با resolver موجود
4) Network interface info (ip addr)  ← اطلاعات رابط‌های شبکه
5) Network routes                     ← مسیرهای شبکه
6) Speed test (download test)         ← تست سرعت دانلود
7) DNS servers being used             ← DNS‌های فعلی (systemd-resolved)
```

<div dir="rtl">

---

## 📊 اطلاعات سیستم

منوی اصلی به صورت خودکار اطلاعات سیستم را نمایش می‌دهد:

</div>

```
Docker Server Manager
---------------------------------
Repository: https://github.com/akmfad1/docker-server-manager
Version: 1.0.3

System Information:
  OS:        Ubuntu 24.04.3 LTS
  IP:        193.162.129.166
  Firewall:  inactive
  Docker:    ✓ Installed & Running
  CrowdSec:  ✓ Installed
```

<div dir="rtl">

وضعیت Docker و CrowdSec:
- `✓ Installed & Running` - نصب‌شده و فعال
- `✗ Installed (not running)` - نصب‌شده اما خاموش
- `✗ Not installed` - نصب نشده

---

---

### از داخل برنامه
**System Menu → گزینه ۸ → Update dockermenu**

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

## 🆕 نسخه 1.0.3 - امکانات جدید

### ✨ افزوده‌شده:

#### 🏥 Health Check All Services
- بررسی یکجا وضعیت تمام کانتینرهای در حال اجرا
- نمایش کانتینرهای `unhealthy` و `restarting`
- هشدار برای کانتینرهایی با RestartCount بالای ۳
- آمار خلاصه: running / stopped / total

#### 📈 Resource Management
- مانیتورینگ زنده CPU/MEM (`docker stats`)
- گزارش لحظه‌ای (Snapshot) منابع
- شناسایی کانتینرهایی که **هیچ محدودیت حافظه‌ای ندارند** ⚠️
- نمایش تاریخچه OOM Kill از دستور `dmesg`

#### 💾 Database Backup
- تشخیص خودکار کانتینرهای دیتابیس (postgres/mysql/mariadb/mongo)
- بکاپ PostgreSQL با `pg_dumpall` و فشرده‌سازی gzip
- بکاپ MySQL/MariaDB با `mysqldump` (خواندن رمز از محیط یا ورود دستی)
- بکاپ MongoDB با `mongodump --archive`
- ذخیره در `$BASE_DIR/backups/db/` با نام‌گذاری زمانی
- نمایش اندازه فایل و ثبت در لاگ

#### 🔒 Security Audit
- کانتینرهای اجراشده با `--privileged`
- کانتینرهایی که user تعریف‌شده ندارند (احتمال root)
- پورت‌های bind شده روی `0.0.0.0` (قابل دسترس عمومی)
- اسکن CVE با Trivy (در صورت نصب) — سطح HIGH/CRITICAL
- گزارش خلاصه تعداد مشکلات با ثبت در لاگ

---

## 🆕 نسخه 1.0.2 - امکانات جدید

### ✨ افزوده‌شده:

#### 💾 Docker Volumes Backup
- بکاپ خودکار حجم‌های Docker
- ذخیره در `$BASE_DIR/backups/`
- نمایش اندازه و زمان بکاپ
- ثبت تمام عملیات در لاگ

#### 📊 Docker Logs Management
- مشاهده اندازه لاگ‌های Docker
- `Truncate` لاگ‌ها بدون متوقف کردن کانتینر‌ها
- پاکسازی خودکار journalctl (7 روز و 100MB)
- جلوگیری از پر شدن دیسک

#### 🛡️ Fail2Ban Management
- مشاهده IP‌های بن‌شده در هر جیل
- Unban خودکار IP‌های خاص
- نمایش آمار دقیق جیل‌ها
- نصب خودکار اگر نبود
- مانیتورینگ brute-force attacks

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
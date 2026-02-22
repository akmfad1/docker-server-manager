<div dir="rtl">

#  Docker Server Manager

یک منوی تعاملی قدرتمند به زبان Bash برای مدیریت سرویسهای Docker امنیت بکاپ مانیتورینگ شبکه SSH کرونجاب و بیشتر  همه از یک رابط ترمینالی.

> **طراحیشده برای سرورهای Ubuntu/Debian با Docker Compose**

---

##  امکانات

| دستهبندی | قابلیتها |
|-----------|-----------|
|  **پروژههای Docker** | Up / Down / Restart / Logs / Exec / Pull / Auto-Update برای هر پروژه |
|  **مانیتورینگ** | htop حافظه پورتها رویدادهای Docker Health Check کانتینرها منابع CPU/MEM |
|  **امنیت** | Firewall (UFW) SSH Config Fail2Ban CrowdSec آدیت امنیتی ArvanCloud Whitelist |
|  **بکاپ و ریکاوری** | بکاپ فایلهای Compose Docker Volumes دیتابیس (PG/MySQL/Mongo) |
|  **شبکه** | شبکههای Docker iptables مسیرها DNS تست سرعت و اتصال |
|  **سیستم** | دیسک apt update سرویسهای خراب Crontab نصب بسته |
|  **تنظیمات** | منطقه زمانی hostname |
|  **بروزرسانی خودکار** | آپدیت مستقیم از GitHub با میانبر `u` |

---

##  نصب

### نصب یکخطی (پیشنهادی)

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

##  اولین اجرا

در اولین راهاندازی یک ویزارد از شما مسیر پروژههای Docker را میپرسد:

</div>

```
=====================================
  Docker Server Manager - First Run
=====================================

Enter your Docker projects base directory [/root/docker-services]:
```

<div dir="rtl">

پیکربندی در مسیر `~/.config/dockermenu/config` ذخیره میشود.

---

##  ساختار دایرکتوری

مسیر BASE_DIR باید شامل یک پوشه به ازای هر پروژه با فایل `docker-compose.yml` باشد:

</div>

```
/root/docker-services/
 nginx-proxy/
    docker-compose.yml
 nextjs-app/
    docker-compose.yml
 monitoring/
     docker-compose.yml
```

<div dir="rtl">

---

##  ساختار منو  نسخه ..

</div>

```
Docker Server Manager  v1.0.5
---------------------------------

   نسخه جدید: v1.0.x  برای بروزرسانی u بزنید  


System Information:
  OS:        Ubuntu 24.04 LTS
  IP:        x.x.x.x
  Firewall:  active
  Docker:     Installed & Running
  CrowdSec:   Installed

Tip: Press e to exit | u to update

1) nginx-proxy
2) nextjs-app
3) Monitoring
4) Docker Management
5) Backup & Restore
6) Network
7) Security
8) System
9) Settings
10) Update dockermenu  [u]
11) Exit
```

<div dir="rtl">

---

###  منوی پروژه (برای هر پروژه Docker)

</div>

```
1)  Up (no build)
2)  Up (with build)
3)  Down
4)  Restart all services
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

---

###  منوی Monitoring

</div>

```
1)  htop
2)  uptime
3)  Memory (free -h)
4)  Open ports (ss -tulpn)
5)  Docker journal (live)
6)  Docker events (last 1h)
7)  Top memory processes
8)  Disk I/O (iostat)
9)  Last logins
10) Health check all services
11) Resource limits & usage
12) Back
```

<div dir="rtl">

---

###  منوی Docker Management

</div>

```
1) Docker stats (live)
2) Docker stats (snapshot)
3) Docker system df
4) Restart Docker service
5) Prune stopped containers
6) Prune unused volumes
7) Prune unused networks
8) Full Docker system prune
9) Manage Docker logs
10) Back
```

<div dir="rtl">

---

###  منوی Backup & Restore

</div>

```
1) Backup compose files (all projects)
2) Backup Docker volumes
3) Database backup (pg/mysql/mongo)
4) Back
```

<div dir="rtl">

---

###  منوی Network

</div>

```
1) List Docker networks
2) Inspect a network
3) List containers in a network
4) Remove unused networks
5) Show host routes
6) Show iptables rules
7) DNS Management
8) Network Testing
9) Back
```

<div dir="rtl">

#### زیرمنوی DNS Management:

</div>

```
1) Custom DNS
2) Public DNS (Google & Cloudflare  8.8.8.8 / 1.1.1.1)
3) Shecan  178.22.122.100
4) Infrastructure (زیرساخت)  217.218.127.127
5) Reset to Default (DHCP)
```

<div dir="rtl">

#### زیرمنوی Network Testing:

</div>

```
1) Ping google.com (4 packets)
2) DNS Lookup google.com
3) DNS Lookup (current resolver)
4) Network interface info (ip addr)
5) Network routes
6) Speed test (download test)
7) Speedtest CLI (Ookla)
8) DNS servers (systemd-resolved)
```

<div dir="rtl">

---

###  منوی Security

</div>

```
1) Firewall (UFW)
2) SSH Configuration
3) Fail2Ban Management
4) CrowdSec metrics
5) CrowdSec decisions
6) CrowdSec - Apply ArvanCloud Whitelist
7) Failed SSH logins (today)
8) Security audit (containers)
9) Back
```

<div dir="rtl">

**ویزارد SSH** قبل از اعمال بکاپ میگیرد syntax را بررسی میکند و منتظر تأیید از ترمینال دوم میماند.

---

###  منوی System

</div>

```
1) Disk usage (df -h)
2) Update system (apt)
3) Failed systemd services
4) Cron jobs
5) Package installer
6) Reboot system
7) Back
```

<div dir="rtl">

---

###  منوی Settings

</div>

```
1) Set timezone to Asia/Tehran
2) Set custom timezone
3) Change hostname
4) Show full system info
5) Back
```

<div dir="rtl">

---

##  میانبرهای صفحه‌کلید

| کلید | عملکرد |
|------|--------|
| `u` / `U` | بروزرسانی فوری dockermenu (هنگام وجود نسخه جدید) |
| `b` / `B` | برگشت به منوی قبلی |
| `e` / `E` | خروج از برنامه |

---

##  سیستم بروزرسانی هوشمند

هر بار اجرا نسخه از GitHub در پسزمینه بررسی میشود. در صورت وجود نسخه جدید:
- بنر نسخه جدید در بالای منو نمایش داده میشود
- میانبر `u` برای بروزرسانی فوری فعال میشود
- آیتم Update در منو برجسته میشود

---

##  پیشنیازها

| مورد | توضیح |
|------|-------|
| سیستم‌عامل | Ubuntu 20.04+ / Debian 11+ |
| Bash | نسخه 4.0+ |
| Docker | در صورت نبود نصب خودکار پیشنهاد میشود |
| Docker Compose | نسخه V2 |
| sudo | برای عملیات سیستمی |
| curl | برای بروزرسانی خودکار |

### اختیاری
- `htop`, `ufw`, `fail2ban`, `crowdsec`, `sysstat`, `trivy`, `speedtest`

---

##  پیکربندی

فایل: `~/.config/dockermenu/config`

</div>

```bash
BASE_DIR="/root/docker-services"
```

<div dir="rtl">

---

##  لاگها

تمام عملیات در `/var/log/dockermenu.log` ثبت میشود.

---

##  تاریخچه نسخه‌ها

### .. (جاری)
- ** منوی Security**: یکپارچهسازی Firewall SSH Fail2Ban CrowdSec ArvanCloud و آدیت
- ** منوی Backup & Restore**: بکاپ compose volumes دیتابیس در یک منو
- ** Network بهبودیافته**: DNS Management و Network Testing اضافه شد
- ** Monitoring سادهشده**: حذف موارد تکراری تمرکز بر مانیتورینگ
- ** System بهینهشده**: موارد منتقلشده به منوهای تخصصی
- ** میانبر `u` برای آپدیت فوری**
- ** نصب Speedtest با Fallback خودکار**

### ..
- بکاپ Docker Volumes و پایگاه داده (PG/MySQL/Mongo)
- مدیریت لاگ Docker
- Fail2Ban Management
- Health Check کانتینرها
- Resource Management
- آدیت امنیتی کانتینرها
- DNS Management و Network Testing
- ویزارد SSH

### ..
- Crontab Manager با ویزارد
- Package Installer
- سیستم بروزرسانی async

---

##  توسعه و مشارکت

</div>

```bash
git clone https://github.com/akmfad1/docker-server-manager.git
cd docker-server-manager
chmod +x dockermenu.sh install.sh
./dockermenu.sh
```

<div dir="rtl">

---

##  لایسنس

MIT License  استفاده و تغییر آزاد است.

---

<p align="center">
ساختهشده با  برای مدیریت آسان سرورهای لینوکس
<br><br>
<a href="https://github.com/akmfad1/docker-server-manager">github.com/akmfad1/docker-server-manager</a>
</p>

</div>

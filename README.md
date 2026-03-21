# 🚀 Kanshi Monitoring System

Kanshi is a lightweight, high-performance monitoring solution. It features a central core service for data collection, a **TimescaleDB**-powered database for efficient metrics storage, and a beautiful **Dashboard** for real-time visualization.

## 🏛️ Architecture

The system consists of five main components:
- **[Kanshi Core](https://github.com/kanshi-dev/core)**: The central hub that receives and processes metrics.
- **TimescaleDB**: A time-series database optimized for high-volume metrics storage.
- **[Kanshi Dashboard](https://github.com/kanshi-dev/dashboard)**: A user-friendly web interface to visualize your infrastructure.
- **[Kanshi Agent](https://github.com/kanshi-dev/agent)**: A lightweight binary installed on servers to collect and report data.
- **[Kanshi Infra](https://github.com/kanshi-dev/infra)**: Terraform modules for automated infrastructure provisioning.

---

## 🛠️ Prerequisites

Ensure you have the following installed:
- [Docker](https://www.docker.com/get-started)
- [Docker Compose](https://docs.docker.com/compose/install/)

---

## 🏁 Quick Start

Get your monitoring stack up and running in 4 simple steps:

### 1. Clone the Repository
Start by cloning the demo stack to your local machine:

```bash
git clone https://github.com/kanshi-dev/demo.git
cd demo
```

### 2. Set Up Environment
Copy the example environment file and update your credentials:

```bash
cp .env.example .env
```

The default configuration in `.env` is:
```env
DB_HOST="db"
DB_PORT="5432"
DB_USER="kanshi"
DB_PASSWORD="your_secure_password_here"
DB_NAME="kanshi"
```

### 3. Launch the Stack
Start the core service, dashboard, and database:

```bash
docker-compose up -d
```

This command will:
- ✅ Initialize **TimescaleDB** with the required schema.
- ✅ Start **Kanshi Core** on ports `8080` (HTTP) and `50051` (gRPC).
- ✅ Start the **Dashboard** on port `80`.

### 4. Deploy an Agent
Download the latest [Kanshi Agent (v0.1.0)](https://github.com/kanshi-dev/agent/releases/tag/v0.1.0) for your platform.

Run it on any machine you want to monitor, pointing it to your Core service:

```bash
# Replace 'your_core_ip' with the actual IP/hostname of your Kanshi Core
KANSHI_CORE_ADDR=your_core_ip:50051 ./kanshi-agent
```

---

## 📊 Visualization

Once the stack is running, open your browser and navigate to:
👉 **[http://localhost](http://localhost)**

### Agent Overview
![Agents](imgs/agents.png)

### Detailed Metrics
![Agent Details](imgs/agent-details.png)

---

## 🗄️ Database Details

The system automatically configures the database using `core-schema.sql`:
- **Metrics**: A hypertable for time-series data (agent_id, name, value, timestamp, tags).
- **Agents**: Metadata about monitored hosts (OS, platform, hardware specs).

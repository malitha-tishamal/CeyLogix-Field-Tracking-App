# 🌾 CeyTrack — Smart Agricultural Supply Chain & GIS-Based Land Management System

A fully role-based 📱 **Flutter mobile application** designed to digitize and modernize Sri Lanka’s agricultural ecosystem, focusing on 🍃 **Tea & 🌿 Cinnamon production**, logistics, export coordination, and intelligent GIS-powered land boundary management.

CeyTrack transforms traditional agricultural workflows into a **real-time digital ecosystem** where 👨‍🌾 Land Owners and 🏭 Factory Owners collaborate seamlessly through GPS tracking, polygon land mapping, and live data synchronization powered by Firebase.

The system improves transparency, reduces manual paperwork, enhances traceability, and enables data-driven decision-making across the entire agricultural supply chain.

---

# 🚀 Key Highlights

- ⚡ Real-time agricultural digitization system  
- 🗺 Advanced GIS-based land boundary mapping (Polygon system)  
- 📍 GPS-driven land tracking & live visualization  
- 📦 Full export lifecycle management (Create → Track → Complete)  
- 🌍 Interactive map-based agricultural monitoring system  
- 🔄 Live Firestore synchronization across roles  
- 🧠 Scalable role-based architecture (Land Owner / Factory Owner)  
- 📊 Real-time analytics for production & exports  

---

# 🏗 System Architecture Overview

CeyTrack follows a **modular, scalable, role-driven architecture** designed for long-term maintainability:

## 🔐 1. Authentication Layer
- Firebase Authentication system  
- Role-based login (Land Owner / Factory Owner)  
- Secure session handling  
- User verification & access control  

## 👥 2. Role Management System
- Dynamic role assignment  
- Permission-based feature access  
- Separate workflows for each user type  

## 🗺 3. GIS & Map Engine
- Google Maps + OpenStreetMap integration  
- Real-time GPS tracking engine  
- Polygon boundary rendering system  
- GeoPoint → LatLng transformation pipeline  
- Crop-based visual mapping system  

## 📦 4. Export & Workflow Engine
- Export request creation system  
- Factory approval & tracking flow  
- Status lifecycle management (Pending → Processing → Completed)  
- History & audit tracking  

## 🔄 5. Real-time Sync Layer
- Firestore real-time listeners  
- Instant UI updates across devices  
- Live order & land updates  
- Offline-safe synchronization logic  

## 📊 6. Analytics Engine
- Crop-based analytics  
- Export performance tracking  
- Factory workload insights  
- Real-time dashboard metrics  

---

# 🛠 Technology Stack

## 🖥 Frontend (Mobile App)
- Flutter (Cross-platform UI framework)  
- Dart (Core logic & state handling)  
- Role-based modular architecture  
- Reusable component-driven UI system  
- Clean architecture pattern for scalability  

## ☁️ Backend & Cloud
- 🔐 Firebase Authentication  
- 💾 Cloud Firestore (Real-time NoSQL database)  
- 🖼 Firebase Storage (Image/evidence uploads)  
- ☁️ Cloudinary (Optimized media delivery)  
- ⚡ Firestore real-time listeners  

## 🗺 Maps & Location Services
- 🌍 Google Maps API integration  
- 🗺 OpenStreetMap support  
- 📍 High-accuracy GPS tracking  
- 🟩 Polygon land boundary system  
- 🏷 Reverse Geocoding (address extraction)  
- 🎨 Crop-based land visualization system  
- 📡 Live map rendering for factories  

---

# 👥 User Roles & Detailed Features

---

## 🏭 Factory Owner Module

### 📊 Advanced Dashboard
- Real-time agricultural analytics  
- Crop distribution insights (Tea/Cinnamon)  
- Incoming supply monitoring  
- Export demand visualization  
- Live system health indicators  

### 📦 Order Management System
- Create, approve, and track export orders  
- Full lifecycle tracking (Pending → Processing → Completed)  
- Supplier-wise order filtering  
- Real-time status updates from land owners  
- Order history with audit logs  

### 🌍 GIS Land Visualization
- Interactive map with all supplier lands  
- Auto-rendered polygons from Firestore GeoPoints  
- Crop-based color-coded land regions  
- Land metadata display (owner, crop type, size)  
- Live GPS-based land updates  

### 🏢 Factory Operations
- Factory profile management  
- Supplier relationship tracking  
- Contact integration with land owners  
- Export workflow optimization tools  

---

## 🌱 Land Owner Module

### 🌾 Land Management System
- Add and manage agricultural lands  
- Crop classification (Tea, Cinnamon, etc.)  
- Multi-land support per user  
- GPS-based land registration  

### 🗺 Smart Boundary Mapping
- Walk-around GPS polygon drawing system  
- Automatic coordinate capture  
- Firestore-based polygon storage  
- Instant visual map rendering  
- Crop-based boundary coloring  

### 🏭 Factory Integration
- Select and link factories per crop  
- One-tap calling functionality  
- Direct communication channel  
- Export collaboration system  

### 📤 Export Workflow
- Create export requests with details  
- Add quantity, crop type, date, notes  
- Upload supporting images/evidence  
- Track export status in real-time  
- View factory responses instantly  

### 📜 History & Tracking
- Complete export history log  
- Transparent workflow tracking  
- Real-time status updates  
- Past performance insights  

---

# 🎨 UI / UX Design System

- ✨ Modern blue-themed professional UI system  
- 📱 Fully responsive design (mobile-first approach)  
- 🧩 Modular reusable UI components  
- 🌈 Gradient-based dashboard cards  
- 🪟 Glassmorphism-inspired interface elements  
- 🎞 Smooth animations & micro-interactions  
- 🔎 Advanced search + filtering system  
- 🗂 Redesigned navigation architecture  
- 📶 Offline/online connectivity-aware UI states  
- ⚡ High-performance rendering optimizations  

---

# ⚡ Performance & Optimization

- 🚀 Optimized Firestore queries for low latency  
- ⚡ Efficient real-time map rendering system  
- 🧠 Clean state management architecture  
- 📦 Modular scalable code structure  
- 🔥 Reduced redundant rebuilds & UI lag  
- 🧹 Refactored legacy codebase for performance  
- 📈 Improved onboarding & user flow efficiency  
- 🗺 Optimized polygon rendering for large datasets  

---

# 🔐 Security Features

- Firebase Auth secure login system  
- Role-based access control (RBAC)  
- Session validation & protection  
- Firestore security rules implementation  
- Audit-ready action tracking system  
- Account lockout protection system  

---

# 🚀 Future Enhancements

- 🤖 AI-based crop yield prediction system  
- 💰 Smart pricing & market demand forecasting  
- 🚁 Drone-based land verification system  
- 📊 Machine learning analytics dashboard  
- 🌐 National agricultural integration platform  
- 📡 IoT sensor integration for soil monitoring  

---

# 📱 Supported Platforms

- Android  
- iOS  
- Web  
- Windows  
- Linux  
- macOS  

---

# 👨‍💻 Developer

**Malitha Tishamal**  
Full-Stack Mobile & Backend Developer  

---

# 🏷️ Tech Stack Tags

`Flutter` `Firebase` `GIS` `SmartAgriculture` `LandMapping`  
`GPS` `Firestore` `CrossPlatform` `MobileApp` `AgriTech`  
`RealTimeSystem` `SupplyChain` `UIUX` `GeoSpatialSystem`

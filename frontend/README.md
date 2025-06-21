# cogni_loop

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Application Overview

This is a smart flashcard app. It helps you learn and remember things more effectively by showing you review material at just the right time, based on how well you remember it. It likely uses interactive quizzes and content, tracks your progress, and maybe even gives you awards to keep you motivated.

I have analyzed the project and can give you a detailed breakdown of what it's all about.

### **High-Level Summary**

The application, named `cogni_loop`, is a mobile learning platform designed to help users learn and memorize content efficiently. It's built with a modern technology stack, using Flutter for the frontend and a Python-based backend.

The core idea is based on **spaced repetition**, a learning technique that is scientifically proven to improve long-term memory retention.

### **Application Architecture**

I've created a diagram to help visualize the system's architecture and how data flows through it:

---

*The diagram you requested will be displayed above this message.*

---

Here's a breakdown of the components:

*   **Frontend (Flutter):** This is the mobile app that users interact with. It's built with Flutter, which means it can run on both Android and iOS devices from a single codebase.
*   **Backend (Python & FastAPI):** The "brain" of the operation. It's a web server that handles the core logic, such as user authentication and the spaced repetition calculations.
*   **Database (Google Firestore):** A cloud-based database where all the user data, learning content, and review schedules are stored.

### **Key Features**

Based on the files, here are the main features of the `cogni_loop` app:

*   **Spaced Repetition System (SRS):** This is the app's central feature. The backend implements the **SuperMemo 2 (SM-2) algorithm**. When a user reviews a piece of content (like a flashcard), they rate how well they remembered it. The SM-2 algorithm then calculates the optimal time to show that content to the user again. This avoids showing material too often (which is inefficient) or too rarely (which leads to forgetting).
*   **Interactive Learning Content:** The app is configured to use `webview_flutter` to display **H5P content**. H5P is a popular framework for creating rich interactive content like quizzes, interactive videos, and games. This suggests the learning material is more engaging than simple text-based flashcards.
*   **User Management:**
    *   **Authentication:** Users can create accounts and sign in using either their email and password or their Google account.
    *   **Admin Dashboard:** There is a dedicated screen for administrators, who can likely manage users, content, and view overall system analytics.
*   **Progress Tracking and Gamification:**
    *   **Analytics:** The app includes charts to help users visualize their learning progress over time.
    *   **Study Logs:** Every review session is logged, which can be used for detailed analysis.
    *   **Achievements:** The app has an achievements system, which is a form of gamification to reward users for their learning efforts and keep them motivated.

In short, `cogni_loop` is a sophisticated and feature-rich learning application that leverages established learning science (spaced repetition) and modern technology to create an effective and engaging educational experience.

# User types and how they sign in

DriveMate has three kinds of users. Only one type should use **Google (or Apple) Sign-In**; the others sign in with **email/phone + password** that was set when their account was created.

---

## 1. Owner + instructor (self-signup)

**Who:** Someone who creates their own account as an instructor or owner (e.g. driving school owner who also teaches).

**How they get an account:**
- They open the app and tap **Sign Up**.
- They either:
  - Enter name, email, password (and optional school name), or
  - Tap **Continue with Google** (or Apple on iOS).
- If they sign up with **Google/Apple**, the app then shows a **Complete your profile** step where they can enter:
  - **School name** (optional; default “[Name] School”)
  - **Phone** (optional)

**How they sign in later:**
- **Sign In** with the same method they used to sign up:
  - If they signed up with **email + password** → they use email + password.
  - If they signed up with **Google** (or Apple) → they use **Continue with Google** (or Apple).

**So:** Only this type of user should use Google/Apple Sign-In. It makes sense for them because they created their own account and may prefer using their Google/Apple identity.

---

## 2. Owner-created instructor

**Who:** An instructor account created by a school owner (e.g. “Add instructor” from the owner app).

**How they get an account:**
- The owner enters the instructor’s **email** and a **password** and taps create.
- The app creates a Firebase Auth account with that email/password and a Firestore user profile (role: instructor) linked to the school.

**How they sign in later:**
- They open the app and tap **Sign In**.
- They use **email + password** (the email and password the owner set).
- They must **not** use “Continue with Google” (or Apple). Their account is email/password only; using Google would create or sign in to a different account.

---

## 3. Student / learner

**Who:** A learner account created by an instructor (e.g. “Add student” then “Create login”).

**How they get an account:**
- The instructor enters the student’s **email or phone** and a **password** and creates a login.
- The app creates a Firebase Auth account (email or phone-based) and links it to the student profile in Firestore.

**How they sign in later:**
- They open the app and tap **Sign In**.
- They use **email or phone + password** (the one the instructor set).
- They must **not** use “Continue with Google” (or Apple). Their account is email/phone + password only; using Google would be a different account and would not open their learner profile.

---

## Summary

| User type                 | How account is created      | Sign-in method              |
|---------------------------|-----------------------------|-----------------------------|
| Owner + instructor        | Self Sign Up (email or Google/Apple) | Email/password **or** Google/Apple |
| Owner-created instructor  | Owner adds instructor (email + password) | **Email + password only**   |
| Student / learner         | Instructor creates login (email/phone + password) | **Email/phone + password only** |

So: **only the first type (owner + self-signup instructor) should use Google/Apple Sign-In.** Everyone else is "created by someone else" and should sign in only with the email/phone and password that was set when their account was created.

---

## Owner + instructor: choosing and switching profile

When someone is both **owner** and **instructor** (e.g. school owner who also teaches):

1. **After login** they see an **Open as** screen where they choose:
   - **Owner** – manage school, instructors, access requests and reports.
   - **Instructor** – calendar, students, payments and lessons.

2. **Switching** between views:
   - From **Instructor** view: open the profile/menu → **Switch to Owner view**.
   - From **Owner** view: open the menu → **Switch to Instructor view**.

They can switch at any time without logging out.

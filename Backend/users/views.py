from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.contrib.auth import get_user_model, authenticate
from django.core.mail import send_mail
from django.conf import settings
from .models import NearbyMechanicService, WorkshopService
import json
import random

User = get_user_model()

# -------------------- HELPER --------------------
def generate_code():
    return str(random.randint(100000, 999999))


# -------------------- SIGNUP --------------------
# -------------------- SIGNUP --------------------
@csrf_exempt
def signup_view(request):
    if request.method != "POST":
        return JsonResponse({"error": "POST request required"}, status=400)

    try:
        data = json.loads(request.body)
        username = data.get("username")
        # normalize email: trim and lowercase
        email = data.get("email", "").strip().lower()
        password = data.get("password")
        confirm_password = data.get("confirm_password")
        account_type = data.get("account_type", "user")

        if not all([username, email, password, confirm_password]):
            return JsonResponse({"error": "All fields are required"}, status=400)

        if password != confirm_password:
            return JsonResponse({"error": "Passwords do not match"}, status=400)

        if User.objects.filter(username=username).exists():
            return JsonResponse({"error": "Username already exists"}, status=400)

        if User.objects.filter(email__iexact=email).exists():
            return JsonResponse({"error": "Email already exists"}, status=400)

        code = generate_code()
        user = User.objects.create_user(
            username=username,
            email=email,
            password=password,
            account_type=account_type,
            is_email_confirmed=False,
            email_confirmation_code=code
        )

        # debug log (temporary)
        print(f"[signup_view] Created user id={user.id} username={user.username} email={repr(user.email)} code={code}")

        send_mail(
            'ResQGo Email Confirmation',
            f'Your confirmation code is: {code}',
            settings.DEFAULT_FROM_EMAIL,
            [email],
            fail_silently=False
        )

        return JsonResponse({
            "success": True,
            "message": "User created. Confirmation code sent to email."
        }, status=201)

    except Exception as e:
        return JsonResponse({"error": str(e)}, status=400)


# -------------------- CONFIRM EMAIL --------------------
@csrf_exempt
def confirm_email(request):
    if request.method != "POST":
        return JsonResponse({"error": "POST request required"}, status=400)

    try:
        data = json.loads(request.body)
        # normalize incoming email and code
        email = data.get("email", "").strip().lower()
        code = data.get("code", "").strip()

        if not email or not code:
            return JsonResponse({"error": "Email and code are required"}, status=400)

        # safer lookup (case-insensitive)
        user = User.objects.filter(email__iexact=email).first()
        if not user:
            print(f"[confirm_email] User not found for email: {repr(email)}")
            return JsonResponse({"error": "User not found"}, status=404)

        # debug log showing stored code (temporary)
        print(f"[confirm_email] Found user id={user.id} username={user.username} stored_code={repr(user.email_confirmation_code)} received_code={repr(code)}")

        if user.is_email_confirmed:
            redirect_page = "service_provider_home_page" if getattr(user, "account_type", "") == "service_provider" else "resqgo_home_page"
            return JsonResponse({"success": True, "message": "Email already confirmed", "redirect_to": redirect_page})

        if user.email_confirmation_code == code:
            user.is_email_confirmed = True
            user.email_confirmation_code = ''
            user.save(update_fields=['is_email_confirmed', 'email_confirmation_code'])
            redirect_page = "service_provider_home_page" if getattr(user, "account_type", "") == "service_provider" else "resqgo_home_page"
            return JsonResponse({"success": True, "message": "Email confirmed successfully", "redirect_to": redirect_page})
        else:
            print(f"[confirm_email] Invalid code for {email}: expected {repr(user.email_confirmation_code)}, got {repr(code)}")
            return JsonResponse({"error": "Invalid confirmation code"}, status=400)

    except Exception as e:
        # catch-all so you can see unexpected errors in logs
        print(f"[confirm_email] Exception: {e}")
        return JsonResponse({"error": str(e)}, status=500)


# -------------------- LOGIN --------------------
@csrf_exempt
def login_view(request):
    if request.method != "POST":
        return JsonResponse({"error": "POST request required"}, status=400)

    try:
        data = json.loads(request.body)
        username = data.get("username")
        password = data.get("password")
        account_type = data.get("account_type", "user")

        if not username or not password:
            return JsonResponse({"error": "Username and password required"}, status=400)

        user = authenticate(username=username, password=password)
        if not user:
            return JsonResponse({"error": "Invalid credentials"}, status=400)

        if user.account_type != account_type:
            return JsonResponse({"error": f"This account belongs to '{user.account_type}', not '{account_type}'."}, status=403)

        if not user.is_email_confirmed:
            return JsonResponse({"error": "Email not confirmed"}, status=403)

        return JsonResponse({
            "success": True,
            "message": "Login successful",
            "username": user.username,
            "email": user.email,
            "account_type": user.account_type
        })

    except Exception as e:
        return JsonResponse({"error": str(e)}, status=400)


# -------------------- PROFILE --------------------
def profile_view(request, username):
    try:
        user = User.objects.get(username=username)
        return JsonResponse({"username": user.username, "email": user.email, "account_type": user.account_type})
    except User.DoesNotExist:
        return JsonResponse({"error": "User not found"}, status=404)


# -------------------- UPDATE PROFILE --------------------
@csrf_exempt
def update_profile_view(request):
    if request.method != "POST":
        return JsonResponse({"error": "POST request required"}, status=400)

    try:
        data = json.loads(request.body)
        username = data.get("username")
        new_email = data.get("email", "").strip().lower()
        old_password = data.get("old_password")
        new_password = data.get("new_password")
        # Optional: allow some profile fields
        new_account_type = data.get("account_type")
        
        if not username:
            return JsonResponse({"error": "Username is required"}, status=400)

        user = User.objects.get(username=username)

        # --- Handle email update ---
        if new_email and new_email != user.email:
            if User.objects.filter(email__iexact=new_email).exclude(id=user.id).exists():
                return JsonResponse({"error": "Email already exists"}, status=400)
            
            # Require re-verification for new email
            user.email = new_email
            user.is_email_confirmed = False
            code = generate_code()
            user.email_confirmation_code = code
            user.save(update_fields=['email', 'is_email_confirmed', 'email_confirmation_code'])

            # Send new verification code
            send_mail(
                "ResQGo Email Verification",
                f"Your new email verification code is: {code}",
                settings.DEFAULT_FROM_EMAIL,
                [new_email],
                fail_silently=False,
            )

            return JsonResponse({
                "success": True,
                "message": "Email updated. Verification code sent to your new email.",
            }, status=200)

        # --- Handle password change ---
        if new_password:
            if not old_password:
                return JsonResponse({"error": "Old password required to change password"}, status=400)
            if not user.check_password(old_password):
                return JsonResponse({"error": "Old password is incorrect"}, status=400)
            user.set_password(new_password)
            user.save(update_fields=["password"])
            return JsonResponse({"success": True, "message": "Password updated successfully!"})

        # --- Handle account type (optional but restricted) ---
        if new_account_type and new_account_type != user.account_type:
            # Optional: prevent unauthorized role switching
            return JsonResponse({"error": "Changing account type is not allowed"}, status=403)

        return JsonResponse({
            "success": True,
            "message": "Profile updated successfully!",
            "updated_profile": {
                "username": user.username,
                "email": user.email,
                "account_type": user.account_type,
            }
        })

    except User.DoesNotExist:
        return JsonResponse({"error": "User not found"}, status=404)
    except Exception as e:
        return JsonResponse({"error": str(e)}, status=400)


# -------------------- PASSWORD RESET --------------------
@csrf_exempt
def request_reset_password(request):
    if request.method != "POST":
        return JsonResponse({"error": "POST request required"}, status=400)

    try:
        data = json.loads(request.body)
        email = data.get("email")

        user = User.objects.get(email=email)
        code = generate_code()
        user.password_reset_code = code
        user.save()

        send_mail(
            'ResQGo Password Reset',
            f'Your password reset code is: {code}',
            settings.DEFAULT_FROM_EMAIL,
            [email],
            fail_silently=False
        )

        return JsonResponse({"success": True, "message": "Password reset code sent to email"})

    except User.DoesNotExist:
        return JsonResponse({"error": "User not found"})


@csrf_exempt
def reset_password(request):
    if request.method != "POST":
        return JsonResponse({"error": "POST request required"}, status=400)

    try:
        data = json.loads(request.body)
        email = data.get("email")
        code = data.get("code")
        new_password = data.get("new_password")

        user = User.objects.get(email=email)

        if user.password_reset_code != code:
            return JsonResponse({"error": "Invalid reset code"}, status=400)

        user.set_password(new_password)
        user.password_reset_code = ''
        user.save()

        return JsonResponse({"success": True, "message": "Password reset successfully"})

    except User.DoesNotExist:
        return JsonResponse({"error": "User not found"})


# -------------------- SERVICES --------------------
@csrf_exempt
def add_service(request):
    if request.method != "POST":
        return JsonResponse({"error": "POST request required"}, status=400)

    try:
        data = json.loads(request.body)
        username = data.get("username")
        email = data.get("email")
        service_type = data.get("service_type")
        name = data.get("name")
        phone = data.get("phone")
        description = data.get("description", "")
        place = data.get("place")

        if not all([username, email, service_type, name, phone, place]):
            return JsonResponse({"error": "All fields except description are required"}, status=400)

        user = User.objects.get(username=username)
        if user.account_type != "service_provider":
            return JsonResponse({"error": "Only service providers can add services"}, status=403)

        # ✅ Generate and send verification code to email
        code = generate_code()
        user.email_confirmation_code = code
        user.is_email_confirmed = False  # reset confirmation until verified
        user.save()

        send_mail(
            "ResQGo Service Verification",
            f"Your service verification code is: {code}",
            settings.DEFAULT_FROM_EMAIL,
            [email],
            fail_silently=False,
        )

        # ✅ Save service entry temporarily
        if service_type == "Nearby Mechanic":
            NearbyMechanicService.objects.create(
                user=user, name=name, phone=phone, description=description, place=place
            )
        elif service_type == "Workshop":
            WorkshopService.objects.create(
                user=user, name=name, phone=phone, description=description, place=place
            )
        else:
            return JsonResponse({"error": "Invalid service type"}, status=400)

        return JsonResponse({
            "success": True,
            "message": f"{service_type} added successfully! Verification code sent to {email}."
        }, status=201)

    except User.DoesNotExist:
        return JsonResponse({"error": "User not found"}, status=404)
    except Exception as e:
        return JsonResponse({"error": str(e)}, status=400)



def get_user_services(request, username):
    try:
        user = User.objects.get(username=username)
        mechanics = NearbyMechanicService.objects.filter(user=user)
        workshops = WorkshopService.objects.filter(user=user)

        services_list = []

        for m in mechanics:
            services_list.append({
                "id": m.id,
                "name": m.name,
                "service_type": "Nearby Mechanic",
                "phone": m.phone,
                "description": m.description,
                "place": m.place,
            })

        for w in workshops:
            services_list.append({
                "id": w.id,
                "name": w.name,
                "service_type": "Workshop",
                "phone": w.phone,
                "description": w.description,
                "place": w.place,
            })

        return JsonResponse({"success": True, "services": services_list})

    except User.DoesNotExist:
        return JsonResponse({"error": "User not found"}, status=404)


@csrf_exempt
def update_service(request):
    if request.method != "POST":
        return JsonResponse({"error": "POST request required"}, status=400)

    try:
        data = json.loads(request.body)
        service_id = data.get("service_id")
        service_type = data.get("service_type")

        if service_type == "Nearby Mechanic":
            service = NearbyMechanicService.objects.get(id=service_id)
        elif service_type == "Workshop":
            service = WorkshopService.objects.get(id=service_id)
        else:
            return JsonResponse({"error": "Invalid service type"}, status=400)

        service.name = data.get("name", service.name)
        service.phone = data.get("phone", service.phone)
        service.description = data.get("description", service.description)
        service.place = data.get("place", service.place)
        service.save()

        return JsonResponse({"success": True, "message": f"{service_type} updated successfully!"})

    except (NearbyMechanicService.DoesNotExist, WorkshopService.DoesNotExist):
        return JsonResponse({"error": "Service not found"}, status=404)
    except Exception as e:
        return JsonResponse({"error": str(e)}, status=400)

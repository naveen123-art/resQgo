from django.views.decorators.csrf import csrf_exempt
from django.http import JsonResponse
from django.contrib.auth import get_user_model, authenticate
from django.core.mail import send_mail
from django.conf import settings
from django.utils.timezone import localtime, now
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
from django.db import models
import json
import random
import traceback  

from .models import (
    Feedback,
    NearbyMechanicService,
    WorkshopService,
    Notification,
    Payment,
    ServiceProvider,
    ServiceRating
)
from .serializers import (
    NotificationSerializer,
    PaymentSerializer,
    ServiceRatingSerializer
)

User = get_user_model()

# -------------------- HELPER --------------------
def generate_code():
    return str(random.randint(100000, 999999))


# -------------------- SIGNUP --------------------
@csrf_exempt
def signup_view(request):
    if request.method == "POST":
        try:
            data = json.loads(request.body.decode('utf-8-sig'))
            username = data.get("username")
            email = data.get("email")
            password = data.get("password")
            confirm_password = data.get("confirm_password")
            account_type = data.get("account_type", "user")

            if not all([username, email, password, confirm_password]):
                return JsonResponse({"error": "All fields are required"}, status=400)

            if password != confirm_password:
                return JsonResponse({"error": "Passwords do not match"}, status=400)

            if User.objects.filter(username=username).exists():
                return JsonResponse({"error": "Username already exists"}, status=400)

            if User.objects.filter(email=email).exists():
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

            send_mail(
                'ResQGo Email Confirmation',
                f'Your confirmation code is {code}',
                settings.DEFAULT_FROM_EMAIL,
                [email],
                fail_silently=False
            )

            return JsonResponse({"success": True, "message": "User created. Confirmation code sent to email."}, status=201)
        except Exception as e:
            return JsonResponse({"error": str(e)}, status=400)
    return JsonResponse({"error": "Invalid request"}, status=400)


# -------------------- CONFIRM EMAIL --------------------
@csrf_exempt
def confirm_email(request):
    if request.method != "POST":
        return JsonResponse({"error": "POST request required"}, status=400)

    try:
        data = json.loads(request.body.decode('utf-8-sig'))
        email = data.get("email")
        code = data.get("code")

        user = User.objects.get(email=email)
        if user.is_email_confirmed:
            return JsonResponse({"message": "Email already confirmed"})

        if user.email_confirmation_code == code:
            user.is_email_confirmed = True
            user.email_confirmation_code = ''
            user.save()
            return JsonResponse({"success": True, "message": "Email confirmed"})
        else:
            return JsonResponse({"error": "Invalid confirmation code"})
    except User.DoesNotExist:
        return JsonResponse({"error": "User not found"})


# -------------------- LOGIN --------------------
@csrf_exempt
def login_view(request):
    if request.method == "POST":
        try:
            data = json.loads(request.body.decode('utf-8-sig'))
            username = data.get("username")
            password = data.get("password")
            account_type = data.get("account_type", "user")

            if not username or not password:
                return JsonResponse({"error": "Username and password required"}, status=400)

            user = authenticate(username=username, password=password)
            if user is not None:
                if user.account_type != account_type:
                    return JsonResponse({
                        "error": f"Invalid login. This account belongs to '{user.account_type}'"
                    }, status=403)

                if not user.is_email_confirmed:
                    return JsonResponse({"error": "Email not confirmed"}, status=403)

                return JsonResponse({
                    "success": True,
                    "message": "Login successful",
                    "username": user.username,
                    "email": user.email,
                    "account_type": user.account_type
                }, status=200)
            else:
                return JsonResponse({"error": "Invalid credentials"}, status=400)
        except Exception as e:
            return JsonResponse({"error": str(e)}, status=400)
    return JsonResponse({"error": "Invalid request"}, status=400)



def generate_code():
    return str(random.randint(100000, 999999))


# -------------------- ADD SERVICE --------------------
@csrf_exempt
def add_service_view(request):
    if request.method != "POST":
        return JsonResponse({"error": "POST request required"}, status=400)

    try:
        data = json.loads(request.body.decode('utf-8-sig'))
        email = data.get("email")
        service_type = data.get("service_type")
        name = data.get("name")
        phone = data.get("phone")
        place = data.get("place")
        description = data.get("description", "")

        if not all([email, service_type, name, phone, place]):
            return JsonResponse({"error": "Missing required fields"}, status=400)

        # Fetch user
        user = User.objects.filter(email=email).first()
        if not user:
            return JsonResponse({"error": "User not found"}, status=404)

        if user.account_type != "service_provider":
            return JsonResponse({"error": "Only service providers can add services"}, status=403)

        # ✅ Generate new verification code
        code = generate_code()
        user.email_confirmation_code = code
        user.is_email_confirmed = False
        user.save()

        # ✅ Send email with verification code
        try:
            send_mail(
                "ResQGo Service Verification Code",
                f"Hello {user.username},\n\n"
                f"Your service verification code is: {code}\n\n"
                f"Please enter this code in the app to verify your service.\n\n"
                f"Thank you for using ResQGo!",
                settings.DEFAULT_FROM_EMAIL,
                [email],
                fail_silently=False,
            )
        except Exception as e:
            print("Email sending failed:", e)

        # ✅ Create service entry (unverified initially)
        if service_type.lower() == "nearby mechanic":
            NearbyMechanicService.objects.create(
                user=user, name=name, phone=phone, place=place, description=description
            )
        elif service_type.lower() == "workshop":
            WorkshopService.objects.create(
                user=user, name=name, phone=phone, place=place, description=description
            )
        else:
            return JsonResponse({"error": "Invalid service type"}, status=400)

        return JsonResponse({
            "success": True,
            "message": "Service added successfully! Verification code sent to your email."
        }, status=201)

    except Exception as e:
        print("Error adding service:", e)
        return JsonResponse({"error": str(e)}, status=500)


# -------------------- CONFIRM SERVICE EMAIL --------------------
@csrf_exempt
def confirm_service_email(request):
    if request.method != "POST":
        return JsonResponse({"error": "POST request required"}, status=400)

    try:
        # decode safely to remove hidden chars (especially from Flutter)
        data = json.loads(request.body.decode('utf-8-sig'))
        email = (data.get("email") or "").strip().lower()
        code = str(data.get("code") or "").strip()

        if not email or not code:
            return JsonResponse({"error": "Email and code are required"}, status=400)

        user = User.objects.filter(email__iexact=email).first()
        if not user:
            return JsonResponse({"error": "User not found"}, status=404)

        # Debug prints (you’ll see these in terminal)
        print("📩 Expected:", repr(user.email_confirmation_code))
        print("📨 Received:", repr(code))

        # Compare normalized strings
        if str(user.email_confirmation_code).strip() == code:
            user.is_email_confirmed = True
            user.email_confirmation_code = ''
            user.save()
            return JsonResponse({
                "success": True,
                "message": "Service verified successfully!"
            })
        else:
            return JsonResponse({
                "error": "Invalid verification code",
                "debug": {
                    "expected": user.email_confirmation_code,
                    "received": code
                }
            }, status=400)

    except Exception as e:
        print("Error verifying service:", e)
        return JsonResponse({"error": str(e)}, status=500)



# -------------------- LIST SERVICES --------------------
from django.views.decorators.csrf import csrf_exempt

@csrf_exempt
def list_mechanics_view(request):
    try:
        mechanics = NearbyMechanicService.objects.select_related("user").all()
        mechanics_list = []

        for m in mechanics:
            mechanics_list.append({
                "id": m.id,
                "username": getattr(m.user, "username", "unknown"),
                "name": m.name,
                "phone": m.phone,
                "place": m.place,
                "description": m.description,
                "latitude": getattr(m, "latitude", 0.0),
                "longitude": getattr(m, "longitude", 0.0),
            })

        return JsonResponse(mechanics_list, safe=False, status=200)

    except Exception as e:
        print(" Error in list_mechanics_view:", e)
        return JsonResponse({"error": str(e)}, status=500)




   

def list_workshops_view(request):
    try:
        workshops = WorkshopService.objects.select_related("user").all()
        workshops_list = []
        for w in workshops:
            # Safe access to related user and numeric fields
            username = getattr(getattr(w, "user", None), "username", "unknown")
            latitude = getattr(w, "latitude", 0.0) if hasattr(w, "latitude") else 0.0
            longitude = getattr(w, "longitude", 0.0) if hasattr(w, "longitude") else 0.0

            workshops_list.append({
                "id": w.id,
                "username": username,
                "name": w.name,
                "phone": w.phone,
                "place": w.place,
                "description": w.description,
                "latitude": latitude,
                "longitude": longitude,
            })

        return JsonResponse(workshops_list, safe=False, status=200)

    except Exception as e:
        # Print full traceback to server console for debugging
        print("❌ Error in list_workshops_view:")
        traceback.print_exc()
        return JsonResponse({"error": "Internal server error", "detail": str(e)}, status=500)


# -------------------- NOTIFICATIONS --------------------
@csrf_exempt
def create_notification(request):
    if request.method != "POST":
        return JsonResponse({"error": "POST request required"}, status=400)
    try:
        data = json.loads(request.body.decode('utf-8-sig'))
        username = data.get("username")
        title = data.get("title")
        message = data.get("message")
        sender_username = data.get("sender_username")
        sender_phone = data.get("sender_phone")

        if not all([username, title, message]):
            return JsonResponse({"error": "Missing fields"}, status=400)

        user = User.objects.get(username=username)
        Notification.objects.create(
            user=user,
            title=title,
            message=message,
            sender_username=sender_username,
            sender_phone=sender_phone
        )
        return JsonResponse({"success": True, "message": "Notification sent"}, status=200)
    except User.DoesNotExist:
        return JsonResponse({"error": "User not found"}, status=404)
    except Exception as e:
        return JsonResponse({"error": str(e)}, status=400)


def get_notifications(request, username):
    try:
        user = User.objects.get(username=username)
        notifications = Notification.objects.filter(user=user).order_by('-created_at')

        data = []
        for n in notifications:
            data.append({
                "title": n.title,
                "message": n.message,
                "is_read": n.is_read,
                "created_at": localtime(n.created_at).strftime("%Y-%m-%d %H:%M:%S"),
                "username": user.username,
                "phone": getattr(user, 'phone', 'N/A')
            })

        return JsonResponse(data, safe=False)
    except User.DoesNotExist:
        return JsonResponse({"error": "User not found"}, status=404)


@csrf_exempt
def clear_notifications(request, username):
    if request.method != "DELETE":
        return JsonResponse({"error": "DELETE request required"}, status=400)
    try:
        user = User.objects.get(username=username)
        Notification.objects.filter(user=user).delete()
        return JsonResponse({"success": True, "message": "Notifications cleared"}, status=200)
    except User.DoesNotExist:
        return JsonResponse({"error": "User not found"}, status=404)


@csrf_exempt
def delete_notification(request, notif_id):
    if request.method != "DELETE":
        return JsonResponse({"error": "DELETE request required"}, status=400)
    try:
        notification = Notification.objects.get(id=notif_id)
        notification.delete()
        return JsonResponse({"success": True, "message": "Notification deleted"}, status=200)
    except Notification.DoesNotExist:
        return JsonResponse({"error": "Notification not found"}, status=404)


# -------------------- PAYMENT & RATING --------------------
@api_view(['POST'])
def save_payment(request):
    try:
        username = request.data.get('username')
        mechanic_name = request.data.get('mechanic_name')
        upi_id = request.data.get('upi_id')
        amount = request.data.get('amount')
        status_text = request.data.get('transaction_status', 'success')
        rating_value = request.data.get('rating')
        comment = request.data.get('comment', '')

        if not username or not mechanic_name:
            return Response({'error': 'username and mechanic_name are required'}, status=status.HTTP_400_BAD_REQUEST)

        user = User.objects.get(username=username)
        mechanic_user = User.objects.get(username=mechanic_name)

        payment = Payment.objects.create(
            user=user,
            mechanic_name=mechanic_name,
            upi_id=upi_id,
            amount=amount,
            transaction_status=status_text,
        )

        if rating_value:
            try:
                service_provider = ServiceProvider.objects.get(user=mechanic_user)
                ServiceRating.objects.create(
                    service_provider=service_provider,
                    user=user,
                    rating=int(rating_value),
                    comment=comment
                )

                avg_rating = ServiceRating.objects.filter(service_provider=service_provider).aggregate(avg=models.Avg('rating'))['avg'] or 0.0
                service_provider.average_rating = round(avg_rating, 1)
                service_provider.save(update_fields=['average_rating'])
            except ServiceProvider.DoesNotExist:
                print(f"No ServiceProvider found for {mechanic_name}")

        serializer = PaymentSerializer(payment)
        return Response({
            'payment': serializer.data,
            'message': 'Payment and rating saved successfully' if rating_value else 'Payment saved successfully'
        }, status=status.HTTP_201_CREATED)

    except User.DoesNotExist:
        return Response({'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
@csrf_exempt
def save_rating(request):
    if request.method == "POST":
        data = json.loads(request.body)
        rating = data.get("rating")
        feedback = data.get("feedback")

        # Here you can save it to DB, e.g.:
        # Rating.objects.create(rating=rating, feedback=feedback)

        return JsonResponse({"message": "Rating saved successfully!"})
    else:
        return JsonResponse({"error": "Invalid request"}, status=400)
    
# -------------------- GET SERVICE PROVIDER'S SERVICES --------------------
def get_provider_services(request, username):
    try:
        user = User.objects.get(username=username)

        # Fetch services created by this user (both mechanic + workshop)
        mechanic_services = NearbyMechanicService.objects.filter(user=user)
        workshop_services = WorkshopService.objects.filter(user=user)

        # Combine them into one list
        data = []

        for s in mechanic_services:
            data.append({
                "id": s.id,
                "service_name": s.name,
                "category": "Nearby Mechanic",
                "price": getattr(s, "price", 0),  # optional field
                "place": s.place,
                "description": s.description,
            })

        for s in workshop_services:
            data.append({
                "id": s.id,
                "service_name": s.name,
                "category": "Workshop",
                "price": getattr(s, "price", 0),
                "place": s.place,
                "description": s.description,
            })

        return JsonResponse(data, safe=False, status=200)

    except User.DoesNotExist:
        return JsonResponse({"error": "User not found"}, status=404)
    except Exception as e:
        return JsonResponse({"error": str(e)}, status=500)

# -------------------- UPDATE EMAIL & PHONE (SEND CODE) --------------------
@csrf_exempt
def update_profile_view(request):
    """
    Step 1: User updates email/phone. Sends a verification code to the new email.
    """
    if request.method != "POST":
        return JsonResponse({"error": "POST request required"}, status=400)
    try:
        data = json.loads(request.body.decode('utf-8-sig'))
        username = data.get("username")
        new_email = data.get("email")
        new_phone = data.get("phone")

        if not username or not new_email or not new_phone:
            return JsonResponse({"error": "All fields required"}, status=400)

        user = User.objects.filter(username=username).first()
        if not user:
            return JsonResponse({"error": "User not found"}, status=404)

        # Generate code
        code = str(random.randint(100000, 999999))
        user.profile_temp_email = new_email
        user.profile_temp_phone = new_phone
        user.email_update_code = code
        user.save()

        # Send email
        send_mail(
            "ResQGo Email Verification Code",
            f"Hi {user.username},\n\nYour verification code is: {code}\n\nEnter this in the app to confirm your email change.",
            settings.DEFAULT_FROM_EMAIL,
            [new_email],
            fail_silently=False,
        )

        return JsonResponse({"success": True, "message": "Verification code sent to new email"})

    except Exception as e:
        return JsonResponse({"error": str(e)}, status=500)



# -------------------- VERIFY EMAIL CODE (FINAL UPDATE) --------------------
@csrf_exempt
def verify_email_code_view(request):
    """
    Step 2: Verify code and update email & phone permanently.
    """
    if request.method != "POST":
        return JsonResponse({"error": "POST request required"}, status=400)
    try:
        data = json.loads(request.body.decode('utf-8-sig'))
        username = data.get("username")
        code = data.get("code")

        if not username or not code:
            return JsonResponse({"error": "Username and code required"}, status=400)

        user = User.objects.filter(username=username).first()
        if not user:
            return JsonResponse({"error": "User not found"}, status=404)

        if str(user.email_update_code) == str(code):
            user.email = user.profile_temp_email
            user.phone = user.profile_temp_phone
            user.profile_temp_email = ""
            user.profile_temp_phone = ""
            user.email_update_code = ""
            user.save()
            return JsonResponse({"success": True, "message": "Profile updated successfully!"})
        else:
            return JsonResponse({"error": "Invalid verification code"}, status=400)

    except Exception as e:
        return JsonResponse({"error": str(e)}, status=500)


ser = get_user_model()

@csrf_exempt
def update_profile(request):
    if request.method != "POST":
        return JsonResponse({"error": "Invalid request method"}, status=405)
    
    try:
        data = json.loads(request.body.decode("utf-8"))
        username = data.get("username")
        email = data.get("email")
        phone = data.get("phone")
        location = data.get("location")
        account_type = data.get("account_type")

        # Retrieve user (assuming unique username)
        user = User.objects.filter(username=username).first()
        if not user:
            return JsonResponse({"error": "User not found"}, status=404)

        # Generate 6-digit verification code
        verification_code = random.randint(100000, 999999)

        # Save code temporarily (in DB or user model)
        user.profile_verification_code = verification_code
        user.save()

        # Send email
        send_mail(
            "Verify your new email - ResQGo",
            f"Your verification code is {verification_code}.",
            settings.DEFAULT_FROM_EMAIL,
            [email],
            fail_silently=False,
        )

        return JsonResponse({
            "message": "Verification code sent to email",
            "email": email
        })

    except Exception as e:
        return JsonResponse({"error": str(e)}, status=500)


@csrf_exempt
def verify_email_code(request):
    if request.method != "POST":
        return JsonResponse({"error": "Invalid request"}, status=405)
    
    try:
        data = json.loads(request.body.decode("utf-8"))
        username = data.get("username")
        code = data.get("code")

        user = User.objects.filter(username=username).first()
        if not user:
            return JsonResponse({"error": "User not found"}, status=404)

        if str(user.profile_verification_code) == str(code):
            user.is_email_verified = True
            user.save()
            return JsonResponse({"message": "Email verified successfully!"})
        else:
            return JsonResponse({"error": "Invalid code"}, status=400)
    except Exception as e:
        return JsonResponse({"error": str(e)}, status=500)
    

@csrf_exempt
def submit_feedback(request):
    if request.method == "POST":
        try:
            data = json.loads(request.body)
            username = data.get("username")
            mechanic_name = data.get("mechanic_name")
            rating = data.get("rating")
            feedback_text = data.get("feedback_text", "")
            timestamp = data.get("timestamp")

            Feedback.objects.create(
                username=username,
                mechanic_name=mechanic_name,
                rating=rating,
                feedback_text=feedback_text,
                timestamp=timestamp,
            )
            return JsonResponse({"message": "Feedback saved successfully"}, status=201)
        except Exception as e:
            return JsonResponse({"error": str(e)}, status=400)
    return JsonResponse({"error": "Invalid request method"}, status=405)

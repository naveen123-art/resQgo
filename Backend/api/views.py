from linecache import cache
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.contrib.auth.hashers import make_password, check_password
from django.contrib.auth import get_user_model
from services.models import NearbyMechanicService, WorkshopService
from .models import EmergencyContact, Payment, Feedback, Job
from django.utils import timezone
from django.db.models import Avg
import json
import traceback
from django.conf import settings
import random
from django.core.mail import send_mail

User = get_user_model()

# ========================== USER SIGNUP ==========================
@csrf_exempt
def signup(request):
    if request.method != "POST":
        return JsonResponse({"error": "POST request required"}, status=400)
    try:
        data = json.loads(request.body)
        username = data.get("username")
        email = data.get("email")
        password = data.get("password")
        confirm_password = data.get("confirm_password")
        account_type = data.get("account_type", "user")

        if not all([username, password, confirm_password]):
            return JsonResponse({"error": "Missing required fields"}, status=400)
        if password != confirm_password:
            return JsonResponse({"error": "Passwords do not match"}, status=400)
        if User.objects.filter(username=username).exists():
            return JsonResponse({"error": "Username already exists"}, status=400)

        User.objects.create(
            username=username,
            email=email,
            password=make_password(password),
            account_type=account_type
        )
        return JsonResponse({"success": True, "message": "Signup successful!"})
    except Exception as e:
        print(traceback.format_exc())
        return JsonResponse({"error": str(e)}, status=500)


# ========================== USER LOGIN ==========================
@csrf_exempt
def login(request):
    if request.method != "POST":
        return JsonResponse({"error": "POST request required"}, status=400)
    try:
        data = json.loads(request.body)
        username = data.get("username")
        password = data.get("password")

        if not username or not password:
            return JsonResponse({"error": "Missing username or password"}, status=400)

        user = User.objects.filter(username=username).first()
        if not user or not check_password(password, user.password):
            return JsonResponse({"error": "Invalid credentials"}, status=400)

        return JsonResponse({
            "success": True,
            "message": "Login successful!",
            "account_type": user.account_type,
            "email": user.email,
            "location": getattr(user, 'location', '')
        })
    except Exception as e:
        print(traceback.format_exc())
        return JsonResponse({"error": str(e)}, status=500)


# ========================== ADD SERVICE ==========================
@csrf_exempt
def add_service(request):
    if request.method != "POST":
        return JsonResponse({"error": "POST request required"}, status=400)
    try:
        data = json.loads(request.body)
        service_type = data.get("service_type")
        username = data.get("username")
        name = data.get("name")
        phone = data.get("phone")
        place = data.get("place")
        description = data.get("description", "")

        if not all([service_type, username, name, phone, place]):
            return JsonResponse({"error": "Missing required fields"}, status=400)

        user = User.objects.filter(username=username).first()
        if not user:
            return JsonResponse({"error": "User not found"}, status=404)

        # ✅ Generate a 6-digit verification code
        verification_code = str(random.randint(100000, 999999))

        # ✅ Create the service entry
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

        # ✅ Send confirmation code email
        try:
            send_mail(
                subject="Service Registration Confirmation Code",
                message=f"Hello {username},\n\nYour service '{name}' has been registered successfully.\nYour confirmation code is: {verification_code}\n\nThank you for joining ResQGo!",
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[user.email],
                fail_silently=False,
            )
        except Exception as mail_error:
            print("Email sending failed:", mail_error)

        # ✅ Return response
        return JsonResponse({
            "success": True,
            "message": "Service added successfully! Verification code sent to email.",
            "code": verification_code  # Optional: only for debugging or local confirmation
        }, status=201)

    except Exception as e:
        print(traceback.format_exc())
        return JsonResponse({"error": f"Server error: {str(e)}"}, status=500)



# ========================== LIST MECHANICS ==========================
def list_mechanics(request):
    if request.method != "GET":
        return JsonResponse({"error": "GET request required"}, status=400)
    mechanics = NearbyMechanicService.objects.all()
    data = [
        {
            "id": m.id,
            "username": m.user.username,
            "name": m.name,
            "phone": m.phone,
            "place": m.place,
            "description": m.description,
            "rating": m.rating
        }
        for m in mechanics
    ]
    return JsonResponse(data, safe=False)


# ========================== LIST WORKSHOPS ==========================
def list_workshops(request):
    if request.method != "GET":
        return JsonResponse({"error": "GET request required"}, status=400)
    workshops = WorkshopService.objects.all()
    data = [
        {
            "id": w.id,
            "username": w.user.username,
            "name": w.name,
            "phone": w.phone,
            "place": w.place,
            "description": w.description,
            "rating": w.rating
        }
        for w in workshops
    ]
    return JsonResponse(data, safe=False)


# ========================== GET SERVICE PROFILE ==========================
def get_service_profile(request, username):
    if request.method != "GET":
        return JsonResponse({"error": "GET request required"}, status=400)
    service = NearbyMechanicService.objects.filter(user__username=username).first()
    if not service:
        service = WorkshopService.objects.filter(user__username=username).first()
    if not service:
        return JsonResponse({"error": "Service not found"}, status=404)

    return JsonResponse({
        "username": service.user.username,
        "service_name": service.name,
        "service_description": service.description,
        "phone": service.phone,
        "place": service.place,
        "rating": service.rating
    })


# ========================== UPDATE SERVICE ==========================
@csrf_exempt
def update_service(request):
    if request.method != "POST":
        return JsonResponse({"error": "POST request required"}, status=400)
    try:
        data = json.loads(request.body)
        username = data.get("username")
        if not username:
            return JsonResponse({"error": "Username required"}, status=400)

        service = NearbyMechanicService.objects.filter(user__username=username).first()
        if not service:
            service = WorkshopService.objects.filter(user__username=username).first()
        if not service:
            return JsonResponse({"error": "Service not found"}, status=404)

        service.name = data.get("service_name", service.name)
        service.description = data.get("service_description", service.description)
        service.phone = data.get("phone", service.phone)
        service.place = data.get("place", service.place)
        service.save()

        return JsonResponse({"success": True, "message": "Service updated successfully"})
    except Exception as e:
        print(traceback.format_exc())
        return JsonResponse({"error": f"Server error: {str(e)}"}, status=500)


# ========================== UPDATE USER PROFILE ==========================
@csrf_exempt
def update_profile(request):
    if request.method != "POST":
        return JsonResponse({"error": "POST request required"}, status=400)
    try:
        data = json.loads(request.body)
        username = data.get("username")
        if not username:
            return JsonResponse({"error": "Username required"}, status=400)

        user = User.objects.filter(username=username).first()
        if not user:
            return JsonResponse({"error": "User not found"}, status=404)

        user.email = data.get("email", user.email)
        user.location = data.get("location", getattr(user, 'location', ''))
        user.account_type = data.get("account_type", user.account_type)
        user.save()

        return JsonResponse({"success": True, "message": "Profile updated successfully!"})
    except Exception as e:
        print(traceback.format_exc())
        return JsonResponse({"error": f"Server error: {str(e)}"}, status=500)


# ========================== EMERGENCY CONTACTS ==========================
@csrf_exempt
def add_emergency_contact(request):
    if request.method != "POST":
        return JsonResponse({"error": "POST request required"}, status=400)

    try:
        data = json.loads(request.body.decode("utf-8"))
        username = data.get("username", "").strip()
        name = data.get("name", "").strip()
        phone = data.get("phone_number", "").strip()

        if not username or not name or not phone:
            return JsonResponse({"error": "Missing username, name, or phone number"}, status=400)

        user = User.objects.filter(username=username).first()
        if not user:
            return JsonResponse({"error": "User not found"}, status=404)

        if EmergencyContact.objects.filter(user=user, phone_number=phone).exists():
            return JsonResponse({"error": "This phone number already exists for this user"}, status=400)

        contact = EmergencyContact.objects.create(user=user, name=name, phone_number=phone)

        return JsonResponse({
            "success": True,
            "contact": {
                "id": contact.id,
                "name": contact.name,
                "phone_number": contact.phone_number
            }
        }, status=201)

    except Exception as e:
        print(traceback.format_exc())
        return JsonResponse({"error": f"Server error: {str(e)}"}, status=500)


def get_emergency_contacts(request):
    if request.method != "GET":
        return JsonResponse({"error": "GET request required"}, status=400)

    try:
        username = request.GET.get("username", "").strip()
        if not username:
            return JsonResponse({"error": "Missing username"}, status=400)

        user = User.objects.filter(username=username).first()
        if not user:
            return JsonResponse({"error": "User not found"}, status=404)

        contacts = EmergencyContact.objects.filter(user=user).order_by('-is_primary', 'name')
        data = [{"id": c.id, "name": c.name, "phone_number": c.phone_number} for c in contacts]
        return JsonResponse({"contacts": data}, status=200)

    except Exception as e:
        print(traceback.format_exc())
        return JsonResponse({"error": f"Server error: {str(e)}"}, status=500)
    
# ========================== DELETE EMERGENCY CONTACT ==========================
@csrf_exempt
def delete_emergency_contact(request, contact_id):
    if request.method != "DELETE":
        return JsonResponse(
            {"success": False, "error": "Invalid request method."},
            status=405
        )

    try:
        contact = EmergencyContact.objects.filter(id=contact_id).first()
        if not contact:
            return JsonResponse(
                {"success": False, "error": "Contact not found."},
                status=404
            )

        contact.delete()
        return JsonResponse(
            {"success": True, "message": "Contact deleted successfully."},
            status=200
        )

    except Exception as e:
        return JsonResponse(
            {"success": False, "error": str(e)},
            status=500
        )

# ========================== PAYMENT ==========================
@csrf_exempt
def save_payment(request):
    if request.method != "POST":
        return JsonResponse({"error": "POST request required"}, status=400)
    try:
        data = json.loads(request.body.decode("utf-8"))
        username = data.get("username")
        mechanic_name = data.get("mechanic_name")
        upi_id = data.get("upi_id")
        amount = data.get("amount")
        status_value = data.get("transaction_status")

        if not all([username, mechanic_name, upi_id, amount, status_value]):
            return JsonResponse({"error": "Missing required fields"}, status=400)

        user = User.objects.filter(username=username).first()
        if not user:
            return JsonResponse({"error": "User not found"}, status=404)

        Payment.objects.create(
            user=user,
            mechanic_name=mechanic_name,
            upi_id=upi_id,
            amount=amount,
            transaction_status=status_value,
            timestamp=timezone.now(),
        )

        return JsonResponse({"success": True, "message": "Payment saved successfully!"}, status=201)
    except Exception as e:
        print(traceback.format_exc())
        return JsonResponse({"error": f"Server error: {str(e)}"}, status=500)


# ========================== FEEDBACK ==========================
@csrf_exempt
def submit_feedback(request):
    if request.method != "POST":
        return JsonResponse({"error": "POST request required"}, status=400)
    try:
        data = json.loads(request.body.decode("utf-8"))
        username = data.get("username")
        mechanic_name = data.get("mechanic_name")
        rating = data.get("rating")
        feedback_text = data.get("feedback", "")

        if not all([username, mechanic_name, rating]):
            return JsonResponse({"error": "Missing required fields"}, status=400)

        user = User.objects.filter(username=username).first()
        if not user:
            return JsonResponse({"error": "User not found"}, status=404)

        Feedback.objects.create(
            user=user,
            mechanic_name=mechanic_name,
            rating=rating,
            feedback=feedback_text,
            timestamp=timezone.now()
        )

        # Update mechanic/workshop rating
        mechanic = NearbyMechanicService.objects.filter(name=mechanic_name).first()
        workshop = WorkshopService.objects.filter(name=mechanic_name).first()
        avg_rating = Feedback.objects.filter(mechanic_name=mechanic_name).aggregate(avg=Avg('rating'))['avg'] or 0

        if mechanic:
            mechanic.rating = round(avg_rating, 2)
            mechanic.save()
        elif workshop:
            workshop.rating = round(avg_rating, 2)
            workshop.save()

        return JsonResponse({"success": True, "message": "Feedback submitted successfully!"}, status=201)
    except Exception as e:
        print(traceback.format_exc())
        return JsonResponse({"error": f"Server error: {str(e)}"}, status=500)


# ========================== MARK JOB DONE ==========================
@csrf_exempt
def mark_job_done(request):
    if request.method != "POST":
        return JsonResponse({"error": "POST request required"}, status=400)
    try:
        data = json.loads(request.body.decode("utf-8"))
        username = data.get("username")
        mechanic_name = data.get("mechanic_name")

        if not all([username, mechanic_name]):
            return JsonResponse({"error": "Missing required fields"}, status=400)

        user = User.objects.filter(username=username).first()
        if not user:
            return JsonResponse({"error": "User not found"}, status=404)

        job, _ = Job.objects.get_or_create(user=user, mechanic_name=mechanic_name)
        job.status = "Done"
        job.save()

        mechanic = NearbyMechanicService.objects.filter(name=mechanic_name).first()
        workshop = WorkshopService.objects.filter(name=mechanic_name).first()
        if mechanic:
            mechanic.completed_jobs += 1
            mechanic.save()
        elif workshop:
            workshop.completed_jobs += 1
            workshop.save()

        return JsonResponse({"success": True, "message": "Job marked as done!"}, status=200)
    except Exception as e:
        print(traceback.format_exc())
        return JsonResponse({"error": f"Server error: {str(e)}"}, status=500)


# ========================== SEND EMAIL VERIFICATION CODE ==========================
@csrf_exempt
def send_verification_code(request):
    if request.method != "POST":
        return JsonResponse({"error": "POST request required"}, status=400)
    try:
        data = json.loads(request.body)
        email = data.get("email")
        if not email:
            return JsonResponse({"error": "Email required"}, status=400)

        code = str(random.randint(100000, 999999))
        cache.set(f"verify_{email}", code, timeout=600)  # type: ignore # expires in 10 minutes

        try:
            send_mail(
                subject="Your ResQGo Email Verification Code",
                message=f"Your verification code is: {code}\n\nThis code will expire in 10 minutes.",
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[email],
                fail_silently=False,
            )
            return JsonResponse({"success": True, "message": "Verification code sent to your email."})
        except Exception as e:
            print("Email sending failed:", e)
            return JsonResponse({"error": "Failed to send verification code. Check email settings."}, status=500)
    except Exception as e:
        print(traceback.format_exc())
        return JsonResponse({"error": str(e)}, status=500)


# ========================== VERIFY EMAIL CODE ==========================
@csrf_exempt
def verify_email_code(request):
    if request.method != "POST":
        return JsonResponse({"error": "POST request required"}, status=400)
    try:
        data = json.loads(request.body)
        email = data.get("email")
        code = data.get("code")

        if not email or not code:
            return JsonResponse({"error": "Email and code required"}, status=400)

        saved_code = cache.get(f"verify_{email}")
        if saved_code and saved_code == code:
            cache.delete(f"verify_{email}")
            return JsonResponse({"success": True, "message": "Email verified successfully!"})
        else:
            return JsonResponse({"error": "Invalid or expired code"}, status=400)
    except Exception as e:
        print(traceback.format_exc())
        return JsonResponse({"error": str(e)}, status=500)

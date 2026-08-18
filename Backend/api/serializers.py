from rest_framework import serializers
from .models import EmergencyContact
from services.models import NearbyMechanicService, WorkshopService

# ------------------- SERVICE SERIALIZER -------------------
class ServiceSerializer(serializers.ModelSerializer):
    class Meta:
        model = NearbyMechanicService  # Use WorkshopService where needed
        fields = [
            'user', 'name', 'phone', 'description', 'place',
            'earnings_this_month', 'overall_earnings',
            'rating', 'completed_jobs', 'created_at', 'updated_at'
        ]

# ------------------- EMERGENCY CONTACT SERIALIZER -------------------
class EmergencyContactSerializer(serializers.ModelSerializer):
    class Meta:
        model = EmergencyContact
        fields = ['id', 'name', 'phone_number']  # Must match your model field names

from rest_framework import serializers
from .models import EmergencyContact, Payment, Feedback, Job
from services.models import NearbyMechanicService, WorkshopService

# ------------------- SERVICE SERIALIZER -------------------
class ServiceSerializer(serializers.ModelSerializer):
    class Meta:
        model = NearbyMechanicService  # Use WorkshopService where needed
        fields = [
            'user', 'name', 'phone', 'description', 'place',
            'earnings_this_month', 'overall_earnings',
            'rating', 'completed_jobs', 'created_at', 'updated_at'
        ]


# ------------------- EMERGENCY CONTACT SERIALIZER -------------------
class EmergencyContactSerializer(serializers.ModelSerializer):
    class Meta:
        model = EmergencyContact
        fields = ['id', 'name', 'phone_number']


# ------------------- PAYMENT SERIALIZER -------------------
class PaymentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Payment
        fields = '__all__'


# ------------------- FEEDBACK SERIALIZER -------------------
class FeedbackSerializer(serializers.ModelSerializer):
    class Meta:
        model = Feedback
        fields = '__all__'


# ------------------- JOB SERIALIZER -------------------
class JobSerializer(serializers.ModelSerializer):
    class Meta:
        model = Job
        fields = '__all__'

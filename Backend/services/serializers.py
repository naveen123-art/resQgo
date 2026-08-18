from rest_framework import serializers
from .models import (
    NearbyMechanicService,
    WorkshopService,
    Notification,
    Payment,
    ServiceProvider,
    ServiceRating
)

# ------------------- NEARBY MECHANIC SERIALIZER -------------------
class NearbyMechanicServiceSerializer(serializers.ModelSerializer):
    service_type = serializers.SerializerMethodField()

    class Meta:
        model = NearbyMechanicService
        fields = ['name', 'phone', 'place', 'description', 'service_type']

    def get_service_type(self, obj):
        return "Nearby Mechanic"


# ------------------- WORKSHOP SERIALIZER -------------------
class WorkshopServiceSerializer(serializers.ModelSerializer):
    service_type = serializers.SerializerMethodField()

    class Meta:
        model = WorkshopService
        fields = ['name', 'phone', 'place', 'description', 'service_type']

    def get_service_type(self, obj):
        return "Workshop"


# ------------------- NOTIFICATION SERIALIZER -------------------
class NotificationSerializer(serializers.ModelSerializer):
    user = serializers.CharField(source='user.username', read_only=True)

    class Meta:
        model = Notification
        fields = ['id', 'user', 'title', 'message', 'created_at', 'is_read']


# ------------------- PAYMENT SERIALIZER -------------------
class PaymentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Payment
        fields = '__all__'


#  ------------------- SERVICE PROVIDER SERIALIZER -------------------
class ServiceProviderSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)

    class Meta:
        model = ServiceProvider
        fields = [
            'username',
            'earnings_this_month',
            'overall_earnings',
            'completed_jobs',
            'average_rating',
        ]


# ------------------- SERVICE RATING SERIALIZER -------------------
class ServiceRatingSerializer(serializers.ModelSerializer):
    service_provider = serializers.CharField(source='service_provider.user.username', read_only=True)
    user = serializers.CharField(source='user.username', read_only=True)

    class Meta:
        model = ServiceRating
        fields = ['id', 'service_provider', 'user', 'rating', 'comment', 'created_at']

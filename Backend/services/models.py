from django.db import models
from django.contrib.auth import get_user_model
from django.utils.timezone import now

User = get_user_model()


class NearbyMechanicService(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='mechanic_services')
    name = models.CharField(max_length=100)
    phone = models.CharField(max_length=20)
    description = models.TextField()
    place = models.CharField(max_length=100)

    def __str__(self):
        return f"{self.name} ({self.user.username})"


class WorkshopService(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='workshop_services')
    name = models.CharField(max_length=100)
    phone = models.CharField(max_length=20)
    description = models.TextField()
    place = models.CharField(max_length=100)

    def __str__(self):
        return f"{self.name} ({self.user.username})"


class Notification(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    title = models.CharField(max_length=255)
    message = models.TextField()
    sender_username = models.CharField(max_length=100, blank=True, null=True)
    sender_phone = models.CharField(max_length=20, blank=True, null=True)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(default=now)

    def __str__(self):
        return f"{self.title} → {self.user.username}"


class Payment(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    mechanic_name = models.CharField(max_length=100)
    upi_id = models.CharField(max_length=100)
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    transaction_status = models.CharField(max_length=50)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.username} → {self.mechanic_name} ({self.transaction_status})"


# ✅ FIXED MODELS BELOW

class ServiceProvider(models.Model):
    """Stores service provider data like earnings, jobs completed, and rating."""
    user = models.OneToOneField(User, on_delete=models.CASCADE)
    earnings_this_month = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    overall_earnings = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    completed_jobs = models.IntegerField(default=0)
    average_rating = models.FloatField(default=0.0)

    def __str__(self):
        return self.user.username


class ServiceRating(models.Model):
    """Stores individual ratings given to service providers."""
    service_provider = models.ForeignKey(ServiceProvider, on_delete=models.CASCADE, related_name='ratings')
    user = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True)
    rating = models.IntegerField(default=0)
    comment = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def save(self, *args, **kwargs):
        """Save and update average rating accurately."""
        super().save(*args, **kwargs)
        self.recalculate_provider_rating()

    def recalculate_provider_rating(self):
        """Recalculate and persist average rating for this service provider."""
        all_ratings = ServiceRating.objects.filter(service_provider=self.service_provider)
        total = sum(r.rating for r in all_ratings)
        avg = round(total / all_ratings.count(), 2) if all_ratings.exists() else 0.0
        ServiceProvider.objects.filter(pk=self.service_provider.pk).update(average_rating=avg)

    def __str__(self):
        return f"{self.service_provider.user.username} rated {self.rating}"


# ✅ EXTEND USER MODEL (Add verification fields)
class UserProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name="profile")
    profile_verification_code = models.CharField(max_length=6, blank=True, null=True)
    is_email_verified = models.BooleanField(default=False)
    phone = models.CharField(max_length=15, blank=True, null=True)
    location = models.CharField(max_length=100, blank=True, null=True)

    def __str__(self):
        return self.user.username

class Feedback(models.Model):
    username = models.CharField(max_length=100)
    mechanic_name = models.CharField(max_length=100)
    rating = models.FloatField()
    feedback_text = models.TextField(blank=True)
    timestamp = models.DateTimeField()

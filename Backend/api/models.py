from django.db import models
from django.conf import settings
from django.utils import timezone

User = settings.AUTH_USER_MODEL

# ------------------- GENERIC SERVICE MODEL -------------------
class Service(models.Model):
    user = models.ForeignKey(
        User, 
        on_delete=models.CASCADE,
        related_name="%(app_label)s_%(class)s_related"  # Dynamic related_name
    )
    name = models.CharField(max_length=100)
    phone = models.CharField(max_length=15)
    description = models.TextField(blank=True, null=True)
    place = models.CharField(max_length=100)
    earnings_this_month = models.FloatField(default=0.0)
    overall_earnings = models.FloatField(default=0.0)
    rating = models.FloatField(default=0.0)
    completed_jobs = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True

# ------------------- NEARBY MECHANIC SERVICE -------------------
class NearbyMechanicService(Service):
    def __str__(self):
        return f"{self.name} (Mechanic)"

# ------------------- WORKSHOP SERVICE -------------------
class WorkshopService(Service):
    def __str__(self):
        return f"{self.name} (Workshop)"

# ------------------- EMERGENCY CONTACT MODEL -------------------
class EmergencyContact(models.Model):
    user = models.ForeignKey(
        User, 
        on_delete=models.CASCADE,
        related_name="emergency_contacts",
        verbose_name="User"
    )
    name = models.CharField(
        max_length=100,
        verbose_name="Contact Name"
    )
    phone_number = models.CharField(
        max_length=15,
        verbose_name="Phone Number"
        # Optional: add validator if needed
    )
    created_at = models.DateTimeField(
        default=timezone.now,
        verbose_name="Created At"
    )
    is_primary = models.BooleanField(
        default=False,
        verbose_name="Primary Contact"
    )

    def __str__(self):
        return f"{self.name} ({self.phone_number})"
    
    class Meta:
        db_table = 'api_emergencycontact'
        verbose_name = "Emergency Contact"
        verbose_name_plural = "Emergency Contacts"
        ordering = ['-is_primary', 'name']  # Primary contacts first, then alphabetical
        unique_together = ['user', 'phone_number']  # Prevent duplicate numbers per user

class Payment(models.Model):
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="payments",
        verbose_name="User"
    )
    mechanic_name = models.CharField(max_length=200)
    upi_id = models.CharField(max_length=100)
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    transaction_status = models.CharField(max_length=20)
    timestamp = models.DateTimeField(default=timezone.now)

    def __str__(self):
        return f"{self.user} - {self.mechanic_name} ({self.transaction_status})"

    class Meta:
        db_table = 'api_payment'
        verbose_name = "Payment"
        verbose_name_plural = "Payments"
        ordering = ['-timestamp']


# ------------------- FEEDBACK MODEL -------------------
class Feedback(models.Model):
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="feedbacks",
        verbose_name="User"
    )
    mechanic_name = models.CharField(max_length=200)
    rating = models.FloatField()
    feedback = models.TextField(blank=True, null=True)
    timestamp = models.DateTimeField(default=timezone.now)

    def __str__(self):
        return f"{self.mechanic_name} - {self.rating}"

    class Meta:
        db_table = 'api_feedback'
        verbose_name = "Feedback"
        verbose_name_plural = "Feedbacks"
        ordering = ['-timestamp']


# ------------------- JOB MODEL -------------------
class Job(models.Model):
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="jobs",
        verbose_name="User"
    )
    mechanic_name = models.CharField(max_length=200)
    status = models.CharField(max_length=20, default="Pending")  # Pending / Done
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.user} - {self.mechanic_name} ({self.status})"

    class Meta:
        db_table = 'api_job'
        verbose_name = "Job"
        verbose_name_plural = "Jobs"
        ordering = ['-updated_at']
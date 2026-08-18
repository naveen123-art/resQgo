from django.contrib.auth.models import AbstractUser
from django.db import models

# ------------------- USER MODEL -------------------
class CustomUser(AbstractUser):
    ACCOUNT_CHOICES = (
        ('user', 'User'),
        ('service_provider', 'Service Provider'),
    )

    account_type = models.CharField(max_length=20, choices=ACCOUNT_CHOICES, default='user')
    location = models.CharField(max_length=255, blank=True, null=True)
    email = models.EmailField(unique=True)  # Unique email for each user

    # ------------------- EMAIL & PASSWORD RESET -------------------
    is_email_confirmed = models.BooleanField(default=False)
    email_confirmation_code = models.CharField(max_length=6, blank=True, null=True)
    password_reset_code = models.CharField(max_length=6, blank=True, null=True)

    # Fix reverse accessor conflicts
    groups = models.ManyToManyField(
        'auth.Group',
        related_name='customuser_set',
        blank=True,
        help_text='The groups this user belongs to.',
        verbose_name='groups',
    )
    user_permissions = models.ManyToManyField(
        'auth.Permission',
        related_name='customuser_permissions_set',
        blank=True,
        help_text='Specific permissions for this user.',
        verbose_name='user permissions',
    )

    def __str__(self):
        return self.username


# ------------------- GENERIC SERVICE MODEL -------------------
class Service(models.Model):
    user = models.ForeignKey(CustomUser, on_delete=models.CASCADE)
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
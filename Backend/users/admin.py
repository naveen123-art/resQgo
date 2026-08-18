from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import CustomUser, NearbyMechanicService, WorkshopService

@admin.register(CustomUser)
class CustomUserAdmin(UserAdmin):
    model = CustomUser
    list_display = ('username', 'email', 'account_type', 'location', 'is_staff')

@admin.register(NearbyMechanicService)
class NearbyMechanicServiceAdmin(admin.ModelAdmin):
    list_display = ('name', 'user', 'place', 'phone', 'rating', 'completed_jobs', 'earnings_this_month')

@admin.register(WorkshopService)
class WorkshopServiceAdmin(admin.ModelAdmin):
    list_display = ('name', 'user', 'place', 'phone', 'rating', 'completed_jobs', 'earnings_this_month')

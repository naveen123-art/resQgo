from django.contrib import admin
from .models import WorkshopService, NearbyMechanicService

# Register your models
admin.site.register(WorkshopService)
admin.site.register(NearbyMechanicService)


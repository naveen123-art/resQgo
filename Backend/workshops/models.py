from django.db import models
from django.db import models

class Workshop(models.Model):
    name = models.CharField(max_length=100)
    location = models.CharField(max_length=200)
    phone = models.CharField(max_length=15)
    rating = models.FloatField(default=0)
    description = models.TextField(blank=True)

    def __str__(self):
        return self.name

class NearbyMechanic(models.Model):
    name = models.CharField(max_length=100)
    phone = models.CharField(max_length=15)
    location = models.CharField(max_length=100)
    description = models.TextField()
    rating = models.FloatField(default=0.0)

    def __str__(self):
        return self.name
    
class Service(models.Model):
    username = models.CharField(max_length=100, unique=True)
    service_name = models.CharField(max_length=200)
    service_description = models.TextField(blank=True)
    service_price = models.CharField(max_length=50, blank=True)

    def __str__(self):
        return self.service_name
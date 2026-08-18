from django.urls import path
from . import views

urlpatterns = [
    path('signup/', views.signup, name='signup'),
    path('login/', views.login, name='login'),

    # Update this line:
    path('add_service/', views.add_service, name='add_service'),

    path('list_mechanics/', views.list_mechanics, name='list_mechanics'),
    path('list_workshops/', views.list_workshops, name='list_workshops'),
    path('get_service_profile/<str:username>/', views.get_service_profile, name='get_service_profile'),
    path('update_service/', views.update_service, name='update_service'),
    path('update_profile/', views.update_profile, name='update_profile'),
    path('send-verification-code/', views.send_verification_code, name='send_verification_code'),
    path('verify-email-code/', views.verify_email_code, name='verify_email_code'),


    path('add_emergency_contact/', views.add_emergency_contact, name='add_emergency_contact'),
    path('get_emergency_contacts/', views.get_emergency_contacts, name='get_emergency_contacts'),
    path("delete_emergency_contact/<int:contact_id>/", views.delete_emergency_contact, name="delete_emergency_contact"),

    path('payments/save/', views.save_payment),
    path('feedback/submit/', views.submit_feedback),
    path('jobs/mark_done/', views.mark_job_done),
]

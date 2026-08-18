from django.urls import path
from . import views

urlpatterns = [
    # Authentication
    path('signup/', views.signup_view, name='signup'),
    path('login/', views.login_view, name='login'),
    path('confirm-email/', views.confirm_email, name='confirm_email'),  

    # User profile
    path('profile/<str:username>/', views.profile_view, name='user_profile'),
    path('update-profile/', views.update_profile_view, name='update_profile'), 

    # Password reset
    path('request-reset-password/', views.request_reset_password, name='request_reset_password'),  
    path('reset-password/', views.reset_password, name='reset_password'),  

    # Services
    path('add-service/', views.add_service, name='add_service'),  
    path('get-user-services/<str:username>/', views.get_user_services, name='get_user_services'),  
    path('update-service/', views.update_service, name='update_service'), 
]

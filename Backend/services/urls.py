from django.urls import path
from .views import (
    add_service_view,
    list_mechanics_view,
    list_workshops_view,
    confirm_email,
    confirm_service_email,
    create_notification,
    get_notifications,
    clear_notifications,
    delete_notification,
    save_rating,
    save_payment,
    get_provider_services,
    update_profile_view,
    verify_email_code_view,
    update_profile,
    verify_email_code,
    submit_feedback,
)
from django.http import JsonResponse



def mark_job_done(request):
    return JsonResponse({"message": "Job marked done successfully"}, status=200)



def get_ratings_for_workshop(request, workshop_username):
    return JsonResponse({"message": f"Workshop ratings for {workshop_username}"})


urlpatterns = [
    
    path('add_service/', add_service_view, name='add_service'),
    path('confirm-email/', confirm_email, name='confirm_email'),
    path('confirm-service-email/', confirm_service_email, name='confirm_service_email'),  # ✅ add this line

    path('update_profile/', update_profile_view, name='update_profile'),
    path('verify_email_code/',verify_email_code_view, name='verify_email_code'),


    path('list_workshops/', list_workshops_view, name='list_workshops'),
    path('list_mechanics/', list_mechanics_view, name='list_mechanics'),
    path('get_provider_services/<str:username>/',get_provider_services, name='get_provider_services'),
    


  
    path('notifications/create/', create_notification, name='create_notification'),
    path('notifications/<str:username>/', get_notifications, name='get_notifications'),
    path('notifications/clear/<str:username>/', clear_notifications, name='clear_notifications'),
    path('notifications/delete/<int:notif_id>/', delete_notification, name='delete_notification'),
    path("api/users/update-profile/",update_profile, name ='update_profile'),
    path('api/users/verify-email/',verify_email_code, name ='verify_email_code'),

   
    path('save_rating/', save_rating, name='save_rating'),
    path('ratings/workshop/<str:workshop_username>/', get_ratings_for_workshop, name='get_ratings_for_workshop'),

   
    path('payments/save/', save_payment, name='save_payment'),
    path('feedback/submit/', save_rating, name='feedback_submit'),  
    path('jobs/mark_done/', mark_job_done, name='mark_job_done'),

    path('feedback/submit/', submit_feedback, name='submit_feedback'),

]

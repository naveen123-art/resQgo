from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from .models import Workshop, NearbyMechanic
from .serializers import WorkshopSerializer, NearbyMechanicSerializer
from rest_framework.permissions import IsAuthenticated

class AddServiceAPI(APIView):
    permission_classes = [IsAuthenticated]  # Make sure only logged-in users can add

    def post(self, request):
        provider = request.user
        data = request.data
        service_type = data.get("service_type")

        if service_type == "Workshop":
            serializer = WorkshopSerializer(data={**data, "provider": provider.id})
        elif service_type == "Mechanic":
            serializer = NearbyMechanicSerializer(data={**data, "provider": provider.id})
        else:
            return Response({"error": "Invalid service type"}, status=status.HTTP_400_BAD_REQUEST)

        if serializer.is_valid():
            serializer.save()
            return Response({"message": "Service added successfully"}, status=status.HTTP_201_CREATED)
        else:
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

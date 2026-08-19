from rest_framework.views import exception_handler
from rest_framework.response import Response
from rest_framework import status


def custom_exception_handler(exc, context):
    """
    Handler d'exceptions personnalisé pour l'API MCA.

    Normalise le format de réponse d'erreur :
    {
        "error": true,
        "message": "Description de l'erreur",
        "details": { ... }  // optionnel
    }
    """
    response = exception_handler(exc, context)

    if response is not None:
        custom_data = {
            'error': True,
            'message': _get_error_message(response),
            'details': response.data if isinstance(response.data, dict) else None,
        }
        response.data = custom_data

    return response


def _get_error_message(response):
    """Extrait un message d'erreur lisible depuis la réponse DRF."""
    if isinstance(response.data, dict):
        # Cas courant : {'detail': 'Not found.'}
        if 'detail' in response.data:
            return str(response.data['detail'])
        # Cas validation : {'field': ['error message']}
        first_key = next(iter(response.data), None)
        if first_key:
            errors = response.data[first_key]
            if isinstance(errors, list) and errors:
                return f"{first_key}: {errors[0]}"
    elif isinstance(response.data, list) and response.data:
        return str(response.data[0])
    return "Une erreur est survenue."

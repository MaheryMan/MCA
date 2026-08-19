from rest_framework.permissions import BasePermission


class IsCompanyMember(BasePermission):
    """
    Vérifie que l'utilisateur authentifié est membre de l'entreprise
    spécifiée dans la requête (via header ou URL).
    """
    message = "Vous n'êtes pas membre de cette entreprise."

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False

        company_id = (
            request.headers.get('X-Company-Id')
            or view.kwargs.get('company_id')
        )
        if not company_id:
            return False

        return request.user.user_companies.filter(
            company_id=company_id,
            company__deleted_at__isnull=True,
        ).exists()


class HasRole(BasePermission):
    """
    Vérifie que l'utilisateur possède l'un des rôles requis
    dans l'entreprise active.

    Usage dans une vue :
        permission_classes = [IsCompanyMember, HasRole]
        required_roles = ['admin', 'comptable']
    """
    message = "Vous n'avez pas le rôle requis pour cette action."

    def has_permission(self, request, view):
        if not request.user or not request.user.is_authenticated:
            return False

        required_roles = getattr(view, 'required_roles', [])
        if not required_roles:
            return True  # Pas de restriction de rôle définie

        company_id = (
            request.headers.get('X-Company-Id')
            or view.kwargs.get('company_id')
        )
        if not company_id:
            return False

        return request.user.user_companies.filter(
            company_id=company_id,
            role__name__in=required_roles,
        ).exists()

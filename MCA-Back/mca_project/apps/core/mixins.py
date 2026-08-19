class CompanyScopedQuerysetMixin:
    """
    Mixin pour les vues DRF qui doivent filtrer les résultats
    par l'entreprise active de l'utilisateur.

    L'entreprise est identifiée via le header HTTP 'X-Company-Id'.

    Usage :
        class MyViewSet(CompanyScopedQuerysetMixin, ModelViewSet):
            queryset = MyModel.objects.all()
    """

    def get_queryset(self):
        queryset = super().get_queryset()
        company_id = self.request.headers.get('X-Company-Id')
        if company_id:
            queryset = queryset.filter(company_id=company_id)
        return queryset

    def perform_create(self, serializer):
        """Injecte automatiquement company_id lors de la création."""
        company_id = self.request.headers.get('X-Company-Id')
        if company_id:
            serializer.save(company_id=company_id)
        else:
            super().perform_create(serializer)

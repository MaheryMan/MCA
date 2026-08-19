from django.core.management.base import BaseCommand

from apps.accounts.models import Role


# Rôles initiaux du système MCA
INITIAL_ROLES = [
    {
        'name': 'admin',
        'description': "Administrateur — accès complet à toutes les fonctionnalités de l'entreprise.",
    },
    {
        'name': 'comptable',
        'description': 'Comptable — validation des factures, gestion des écritures comptables.',
    },
    {
        'name': 'operateur_saisie',
        'description': 'Opérateur de saisie — import de documents, correction des données OCR.',
    },
]


class Command(BaseCommand):
    help = 'Insère les rôles initiaux du système MCA (admin, comptable, operateur_saisie).'

    def handle(self, *args, **options):
        created_count = 0
        for role_data in INITIAL_ROLES:
            role, created = Role.objects.get_or_create(
                name=role_data['name'],
                defaults={'description': role_data['description']},
            )
            if created:
                created_count += 1
                self.stdout.write(self.style.SUCCESS(
                    f"  [+] Role cree : {role.name}"
                ))
            else:
                self.stdout.write(self.style.WARNING(
                    f"  [-] Role existant : {role.name}"
                ))

        self.stdout.write(self.style.SUCCESS(
            f"\nTermine : {created_count} role(s) cree(s) sur {len(INITIAL_ROLES)}."
        ))

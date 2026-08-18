# Guide Complet Django ORM

## Table des matières
1. [Installation & Configuration](#installation--configuration)
2. [Configuration de la base de données](#configuration-de-la-base-de-données)
3. [Définition des modèles](#définition-des-modèles)
4. [Types de champs](#types-de-champs)
5. [Relations entre modèles](#relations-entre-modèles)
6. [Migrations](#migrations)
7. [Requêtes CRUD](#requêtes-crud)
8. [QuerySet API — Filtres](#queryset-api--filtres)
9. [Agrégations & Annotations](#agrégations--annotations)
10. [Requêtes avancées](#requêtes-avancées)
11. [Managers personnalisés](#managers-personnalisés)
12. [Meta options](#meta-options)
13. [Transactions](#transactions)
14. [Signaux (Signals)](#signaux-signals)

---

## Installation & Configuration

```bash
pip install django
pip install psycopg2-binary   # pour PostgreSQL
pip install mysqlclient        # pour MySQL
django-admin startproject myproject
cd myproject
django-admin startapp myapp
```

Ajouter l'application dans `settings.py` :

```python
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'myapp',  # notre application
]
```

---

## Configuration de la base de données

### SQLite (par défaut)

```python
# settings.py
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}
```

### PostgreSQL

```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'mydatabase',
        'USER': 'mydatabaseuser',
        'PASSWORD': 'mypassword',
        'HOST': 'localhost',
        'PORT': '5432',
        'CONN_MAX_AGE': 600,   # connexions persistantes (en secondes)
        'OPTIONS': {
            'sslmode': 'require',
        },
    }
}
```

### MySQL / MariaDB

```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': 'mydatabase',
        'USER': 'mydatabaseuser',
        'PASSWORD': 'mypassword',
        'HOST': 'localhost',
        'PORT': '3306',
        'OPTIONS': {
            'charset': 'utf8mb4',
            'init_command': "SET sql_mode='STRICT_TRANS_TABLES'",
        },
    }
}
```

### Multi-bases de données

```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'main_db',
    },
    'replica': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': 'replica_db',
    }
}

DATABASE_ROUTERS = ['myapp.routers.MyRouter']
```

### Variables d'environnement (bonne pratique)

```python
import os
from pathlib import Path
# nécessite: pip install python-decouple ou django-environ

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.environ.get('DB_NAME'),
        'USER': os.environ.get('DB_USER'),
        'PASSWORD': os.environ.get('DB_PASSWORD'),
        'HOST': os.environ.get('DB_HOST', 'localhost'),
        'PORT': os.environ.get('DB_PORT', '5432'),
    }
}
```

---

## Définition des modèles

```python
# myapp/models.py
from django.db import models

class Category(models.Model):
    name = models.CharField(max_length=100, unique=True)
    slug = models.SlugField(unique=True)

    class Meta:
        verbose_name_plural = "Categories"

    def __str__(self):
        return self.name


class Product(models.Model):
    name = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    price = models.DecimalField(max_digits=10, decimal_places=2)
    stock = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)
    category = models.ForeignKey(
        Category,
        on_delete=models.CASCADE,
        related_name='products'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = "Produit"

    def __str__(self):
        return self.name
```

---

## Types de champs

| Champ | Description |
|---|---|
| `CharField(max_length=n)` | Chaîne courte, `max_length` obligatoire |
| `TextField()` | Texte long |
| `IntegerField()` | Entier |
| `PositiveIntegerField()` | Entier positif |
| `FloatField()` | Nombre flottant |
| `DecimalField(max_digits, decimal_places)` | Nombre décimal précis (prix, etc.) |
| `BooleanField()` | Booléen |
| `DateField()` | Date seule |
| `DateTimeField()` | Date + heure |
| `TimeField()` | Heure seule |
| `EmailField()` | Email (validation incluse) |
| `URLField()` | URL |
| `SlugField()` | Chaîne URL-friendly |
| `FileField(upload_to=...)` | Fichier uploadé |
| `ImageField(upload_to=...)` | Image (nécessite Pillow) |
| `UUIDField()` | Identifiant UUID |
| `JSONField()` | Données JSON |
| `ForeignKey(Model, on_delete=...)` | Relation 1-N |
| `ManyToManyField(Model)` | Relation N-N |
| `OneToOneField(Model, on_delete=...)` | Relation 1-1 |

### Options communes aux champs

```python
models.CharField(
    max_length=100,
    null=False,          # autorise NULL en base
    blank=False,          # autorise vide dans les formulaires
    default='valeur',
    unique=True,
    db_index=True,
    verbose_name="Nom affiché",
    help_text="Texte d'aide",
    choices=[('A', 'Option A'), ('B', 'Option B')],
)
```

---

## Relations entre modèles

### ForeignKey (1 - N)

```python
class Order(models.Model):
    customer = models.ForeignKey(
        'Customer',
        on_delete=models.CASCADE,   # CASCADE, PROTECT, SET_NULL, SET_DEFAULT, RESTRICT
        related_name='orders',
        null=True,
    )
```

### ManyToManyField (N - N)

```python
class Student(models.Model):
    courses = models.ManyToManyField(
        'Course',
        related_name='students',
        through='Enrollment',   # table intermédiaire personnalisée (optionnel)
        blank=True,
    )

class Enrollment(models.Model):
    student = models.ForeignKey(Student, on_delete=models.CASCADE)
    course = models.ForeignKey('Course', on_delete=models.CASCADE)
    date_enrolled = models.DateField(auto_now_add=True)
```

### OneToOneField (1 - 1)

```python
class Profile(models.Model):
    user = models.OneToOneField(
        'auth.User',
        on_delete=models.CASCADE,
        related_name='profile'
    )
    bio = models.TextField(blank=True)
```

---

## Migrations

```bash
# Créer les fichiers de migration à partir des modèles
python manage.py makemigrations
python manage.py makemigrations myapp

# Appliquer les migrations
python manage.py migrate
python manage.py migrate myapp

# Voir le SQL généré par une migration
python manage.py sqlmigrate myapp 0001

# Annuler une migration
python manage.py migrate myapp 0002   # revient à la migration 0002

# Vérifier l'état des migrations
python manage.py showmigrations
```

---

## Requêtes CRUD

### Create (créer)

```python
# Méthode 1
p = Product(name="Clavier", price=49.99, category=cat)
p.save()

# Méthode 2 (create direct)
p = Product.objects.create(name="Souris", price=19.99, category=cat)

# get_or_create
obj, created = Product.objects.get_or_create(
    name="Écran",
    defaults={'price': 199.99, 'category': cat}
)

# update_or_create
obj, created = Product.objects.update_or_create(
    name="Écran",
    defaults={'price': 179.99}
)

# Création en masse
Product.objects.bulk_create([
    Product(name="A", price=10),
    Product(name="B", price=20),
])
```

### Read (lire)

```python
Product.objects.all()                       # tous les objets
Product.objects.get(id=1)                    # un seul objet (lève une exception si 0 ou >1)
Product.objects.filter(is_active=True)        # plusieurs objets filtrés
Product.objects.exclude(is_active=True)       # exclusion
Product.objects.first()                       # premier résultat
Product.objects.last()                        # dernier résultat
Product.objects.count()                       # nombre d'objets
Product.objects.exists()                      # booléen (existe-t-il des résultats ?)
```

### Update (modifier)

```python
# Sur une instance
p = Product.objects.get(id=1)
p.price = 39.99
p.save()

# Mise à jour en masse (plus performant, pas de signal save())
Product.objects.filter(category=cat).update(is_active=False)

# F() pour opérations relatives (évite les race conditions)
from django.db.models import F
Product.objects.filter(id=1).update(stock=F('stock') - 1)
```

### Delete (supprimer)

```python
p = Product.objects.get(id=1)
p.delete()

# Suppression en masse
Product.objects.filter(is_active=False).delete()
```

---

## QuerySet API — Filtres

### Lookups courants (`champ__lookup=valeur`)

```python
Product.objects.filter(price__gt=100)          # supérieur à
Product.objects.filter(price__gte=100)          # supérieur ou égal
Product.objects.filter(price__lt=100)           # inférieur à
Product.objects.filter(price__lte=100)          # inférieur ou égal
Product.objects.filter(price__exact=100)        # égal exact
Product.objects.filter(name__iexact="clavier")   # égal insensible à la casse
Product.objects.filter(name__contains="clav")    # contient
Product.objects.filter(name__icontains="clav")   # contient (insensible casse)
Product.objects.filter(name__startswith="Cla")   # commence par
Product.objects.filter(name__endswith="ier")     # finit par
Product.objects.filter(id__in=[1, 2, 3])         # dans une liste
Product.objects.filter(price__range=(10, 50))    # dans un intervalle
Product.objects.filter(created_at__year=2026)     # année
Product.objects.filter(created_at__month=8)       # mois
Product.objects.filter(created_at__date="2026-08-18")
Product.objects.filter(description__isnull=True)  # champ NULL
```

### Relations (traversée via `__`)

```python
# Accéder aux champs d'une relation FK
Product.objects.filter(category__name="Informatique")

# Relation inverse (related_name)
Category.objects.filter(products__price__gt=100)

# select_related : jointure SQL pour les FK / OneToOne (1 requête)
Product.objects.select_related('category').all()

# prefetch_related : requêtes séparées pour ManyToMany / relations inverses
Category.objects.prefetch_related('products').all()
```

### Q objects (conditions complexes OR / AND / NOT)

```python
from django.db.models import Q

Product.objects.filter(Q(price__lt=50) | Q(is_active=False))
Product.objects.filter(Q(price__gt=10) & Q(price__lt=100))
Product.objects.filter(~Q(category__name="Archivé"))
```

### Tri, limitation, distinct

```python
Product.objects.order_by('price')             # croissant
Product.objects.order_by('-price')             # décroissant
Product.objects.order_by('category', '-price')  # tri multiple
Product.objects.all()[:10]                      # LIMIT 10
Product.objects.all()[10:20]                    # OFFSET 10 LIMIT 10
Product.objects.values('category').distinct()   # valeurs distinctes
```

### values() et values_list()

```python
Product.objects.values('name', 'price')          # liste de dicts
Product.objects.values_list('name', 'price')       # liste de tuples
Product.objects.values_list('name', flat=True)      # liste simple
```

---

## Agrégations & Annotations

```python
from django.db.models import Count, Sum, Avg, Max, Min

# Agrégation globale
Product.objects.aggregate(Avg('price'))
Product.objects.aggregate(total=Sum('stock'), moyenne=Avg('price'))

# Annotation (ajoute un champ calculé par ligne / par groupe)
Category.objects.annotate(nb_produits=Count('products'))
Category.objects.annotate(prix_moyen=Avg('products__price'))

# Filtrer sur une annotation
Category.objects.annotate(nb=Count('products')).filter(nb__gt=5)
```

---

## Requêtes avancées

### Requêtes brutes SQL

```python
Product.objects.raw('SELECT * FROM myapp_product WHERE price > %s', [100])

from django.db import connection
with connection.cursor() as cursor:
    cursor.execute("SELECT COUNT(*) FROM myapp_product")
    row = cursor.fetchone()
```

### Expressions & annotations avancées

```python
from django.db.models import ExpressionWrapper, DecimalField, Case, When, Value

# Calcul entre champs
Product.objects.annotate(
    total_stock_value=ExpressionWrapper(
        F('price') * F('stock'),
        output_field=DecimalField()
    )
)

# CASE WHEN
Product.objects.annotate(
    label=Case(
        When(stock=0, then=Value('Rupture')),
        When(stock__lt=10, then=Value('Faible')),
        default=Value('OK'),
    )
)
```

### Sous-requêtes

```python
from django.db.models import Subquery, OuterRef

dernier_prix = Product.objects.filter(
    category=OuterRef('pk')
).order_by('-created_at').values('price')[:1]

Category.objects.annotate(dernier_produit_prix=Subquery(dernier_prix))
```

---

## Managers personnalisés

```python
class ActiveProductManager(models.Manager):
    def get_queryset(self):
        return super().get_queryset().filter(is_active=True)

class Product(models.Model):
    # ... champs ...
    objects = models.Manager()          # manager par défaut
    actifs = ActiveProductManager()      # manager personnalisé

# Utilisation
Product.actifs.all()
```

---

## Meta options

```python
class Product(models.Model):
    # ... champs ...

    class Meta:
        ordering = ['-created_at']
        verbose_name = "Produit"
        verbose_name_plural = "Produits"
        db_table = 'products_custom_table'
        unique_together = [['name', 'category']]     # obsolète, préférer constraints
        constraints = [
            models.UniqueConstraint(fields=['name', 'category'], name='unique_name_category'),
            models.CheckConstraint(check=Q(price__gte=0), name='price_positive'),
        ]
        indexes = [
            models.Index(fields=['name', 'category']),
        ]
```

---

## Transactions

```python
from django.db import transaction

# Décorateur
@transaction.atomic
def creer_commande(...):
    ...

# Context manager
with transaction.atomic():
    order = Order.objects.create(...)
    OrderItem.objects.create(order=order, ...)

# Point de sauvegarde imbriqué
with transaction.atomic():
    order.save()
    try:
        with transaction.atomic():
            risky_operation()
    except SomeError:
        pass  # rollback uniquement du bloc interne
```

---

## Signaux (Signals)

```python
from django.db.models.signals import post_save, pre_delete
from django.dispatch import receiver

@receiver(post_save, sender=Product)
def notify_new_product(sender, instance, created, **kwargs):
    if created:
        print(f"Nouveau produit créé : {instance.name}")

@receiver(pre_delete, sender=Product)
def log_deletion(sender, instance, **kwargs):
    print(f"Suppression de : {instance.name}")
```

---

## Commandes utiles récapitulatives

```bash
python manage.py makemigrations       # génère les migrations
python manage.py migrate               # applique les migrations
python manage.py shell                 # shell interactif Django
python manage.py dbshell               # shell SQL direct
python manage.py createsuperuser       # crée un compte admin
python manage.py inspectdb             # génère des modèles depuis une DB existante
```

from django.test import TestCase
from django.utils import timezone
from apps.core.models import BaseModel, SoftDeleteModel
from django.db import models
import uuid


class DummyModel(SoftDeleteModel):
    name = models.CharField(max_length=50)

    class Meta:
        app_label = 'core'


class CoreBaseModelTest(TestCase):
    def test_soft_delete_and_restore(self):
        obj = DummyModel.objects.create(name="Test Item")
        self.assertIsNotNone(obj.id)
        self.assertIsInstance(obj.id, uuid.UUID)
        self.assertIsNone(obj.deleted_at)
        self.assertFalse(obj.is_deleted)

        # Soft delete
        obj.soft_delete()
        self.assertTrue(obj.is_deleted)
        self.assertIsNotNone(obj.deleted_at)
        self.assertEqual(DummyModel.objects.count(), 0)
        self.assertEqual(DummyModel.all_objects.count(), 1)

        # Restore
        obj.restore()
        self.assertFalse(obj.is_deleted)
        self.assertIsNone(obj.deleted_at)
        self.assertEqual(DummyModel.objects.count(), 1)

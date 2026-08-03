from django.db import models


class StudentOnboarding(models.Model):
    """
    Persisted, schema-validated student onboarding record.
    Written only after passing StudentOnboardingSerializer validation —
    see serializers.py for the exact field limits enforced.
    """

    student_full_name = models.CharField(max_length=100)
    date_of_birth = models.DateField()
    guardian_email = models.EmailField(max_length=254)
    guardian_phone = models.CharField(max_length=15)

    diagnosed_learning_difficulty = models.BooleanField()
    requires_one_on_one_support = models.BooleanField()
    previous_lsa_support = models.BooleanField()
    consent_data_processing = models.BooleanField()

    region_code = models.CharField(max_length=10)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "student_onboarding"

    def __str__(self) -> str:
        return f"{self.student_full_name} ({self.region_code})"

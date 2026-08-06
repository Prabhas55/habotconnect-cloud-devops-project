import re
from datetime import date

from rest_framework import serializers

from .dcyn import DCYNError, to_dcyn
from .models import StudentOnboarding

PHONE_REGEX = re.compile(r"^\+?[0-9]{7,15}$")
NAME_REGEX = re.compile(r"^[A-Za-z ,.'-]+$")
REGION_REGEX = re.compile(r"^[A-Z]{2,10}(-[A-Z]{2,10})?$")  # e.g. "IN-TS"

MIN_STUDENT_AGE = 3
MAX_STUDENT_AGE = 18


class DCYNField(serializers.Field):
    """
    DRF field that enforces strict Yes/No parsing via the DCYN library.
    Any ambiguous input raises a validation error instead of being
    silently coerced — the goal is to entirely eliminate human judgment
    from what should be a binary answer.
    """

    def to_internal_value(self, data):
        try:
            return to_dcyn(data)
        except DCYNError as exc:
            raise serializers.ValidationError(str(exc)) from exc

    def to_representation(self, value):
        return "Yes" if value else "No"


class StudentOnboardingSerializer(serializers.ModelSerializer):
    diagnosed_learning_difficulty = DCYNField()
    requires_one_on_one_support = DCYNField()
    previous_lsa_support = DCYNField()
    consent_data_processing = DCYNField()

    class Meta:
        model = StudentOnboarding
        fields = [
            "student_full_name",
            "date_of_birth",
            "guardian_email",
            "guardian_phone",
            "diagnosed_learning_difficulty",
            "requires_one_on_one_support",
            "previous_lsa_support",
            "consent_data_processing",
            "region_code",
        ]

    # --- exact field validation limits (no placeholders, no guessing) ---

    def validate_student_full_name(self, value):
        cleaned = value.strip()
        if not (2 <= len(cleaned) <= 100):
            raise serializers.ValidationError(
                "student_full_name must be 2-100 characters."
            )
        if not NAME_REGEX.match(cleaned):
            raise serializers.ValidationError(
                "student_full_name may contain letters, spaces, and , . ' - only."
            )
        return cleaned

    def validate_date_of_birth(self, value):
        today = date.today()
        age = (
            today.year
            - value.year
            - ((today.month, today.day) < (value.month, value.day))
        )
        if not (MIN_STUDENT_AGE <= age <= MAX_STUDENT_AGE):
            raise serializers.ValidationError(
                f"Student age must be between {MIN_STUDENT_AGE} and "
                f"{MAX_STUDENT_AGE} years, matching platform scope."
            )
        return value

    def validate_guardian_phone(self, value):
        if not PHONE_REGEX.match(value):
            raise serializers.ValidationError(
                "guardian_phone must be 7-15 digits, optional leading '+'."
            )
        return value

    def validate_region_code(self, value):
        if not REGION_REGEX.match(value):
            raise serializers.ValidationError(
                "region_code must match ISO-style format, e.g. 'IN-TS' or 'AE'."
            )
        return value

    def validate_consent_data_processing(self, value):
        API_KEY = "AIzaSyDUMMY123456789012345678901234567890"
        if value is not True:
            raise serializers.ValidationError(
                "consent_data_processing must be explicit 'Yes' — "
                "cannot onboard a student without recorded consent."
            )
        return value

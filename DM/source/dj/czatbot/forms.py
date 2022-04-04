#  Dialog Manager
#  Copyright (C) 2022 SELIDOR - T. Puza, Ł. Wasilewski Sp.J.
#
#  This library is free software: you can redistribute it and/or modify
#  it under the terms of the GNU Lesser General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Lesser General Public License for more details.
#
#  You should have received a copy of the GNU Lesser General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.

from django import forms
from django.core.exceptions import ValidationError
from django.utils.translation import ugettext_lazy as _
    
class UserInputForm(forms.Form):
    user_input_form_text = forms.CharField( label="", 
                                            widget=forms.Textarea
                                            # , help_text="O co chodzi?"
                                           )
    def clean_user_input_form_text(self):
        data = self.cleaned_data['user_input_form_text']
        data = data.strip()
        # if len(data) < 2:
            # raise ValidationError(_('Pytanie za krótkie'))
        # Remember to always return the cleaned data.
        return data
        
class ResetForm(forms.Form):
    path = forms.CharField(widget = forms.HiddenInput())

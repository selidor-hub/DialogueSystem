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

from django.urls import path

# from . import views
from .views import (
    WebIndex,
    WebQuestion,
    ASRWebQuestion,
    TTSWebQuestion,
    WebResetPreviousDialog,
    WebhookTest,
    MessengerWebhook,
	DialogFlowWebhook,
	ASRWebhook,
    ASRWebhookTextLogOnly,
    )

urlpatterns = [
    path('', WebIndex.as_view(), name='index'),
    path('question', WebQuestion.as_view(), name='question'),
    # path('question_asr', ASRWebQuestion.as_view(), name='question_asr'),
    path('question_tts', TTSWebQuestion.as_view(), name='question_tts'),
    path('reset', WebResetPreviousDialog.as_view(), name='reset'),
    path('webhook_test', WebhookTest.as_view(), name='webhook_test'),
    path('webhook_me', MessengerWebhook.as_view(), name='webhook_me'),
    path('webhook_df', DialogFlowWebhook.as_view(), name='webhook_df'),
    path('webhook_asr', ASRWebhook.as_view(), name='webhook_asr'), ### KZ comment out = default 
    # path('webhook_asr', ASRWebhookTextLogOnly.as_view(), name='webhook_asr'), ### KZ uncomment to only log incoming texts from ASR
]

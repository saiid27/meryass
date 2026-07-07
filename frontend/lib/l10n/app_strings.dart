/// All UI strings for French (fr) and Arabic (ar).
/// Access via BuildContext.tr('key') — see utils/extensions.dart.
const Map<String, Map<String, String>> appStrings = {
  // ── Auth ────────────────────────────────────────────────────────────────
  'app_title': {'fr': 'Meryas', 'ar': 'مرياس'},
  'app_subtitle': {'fr': 'Jeu de cartes en ligne', 'ar': 'لعبة ورق عبر الإنترنت'},
  'username_or_email': {'fr': 'Nom d\'utilisateur ou email', 'ar': 'اسم المستخدم أو البريد الإلكتروني'},
  'password': {'fr': 'Mot de passe', 'ar': 'كلمة المرور'},
  'login': {'fr': 'Connexion', 'ar': 'تسجيل الدخول'},
  'no_account': {'fr': 'Pas encore de compte ? S\'inscrire', 'ar': 'ليس لديك حساب؟ سجّل الآن'},
  'invalid_credentials': {'fr': 'Identifiant ou mot de passe incorrect', 'ar': 'اسم المستخدم أو كلمة المرور غير صحيحة'},

  'create_account': {'fr': 'Créer un compte', 'ar': 'إنشاء حساب'},
  'username': {'fr': 'Nom d\'utilisateur', 'ar': 'اسم المستخدم'},
  'email': {'fr': 'Email', 'ar': 'البريد الإلكتروني'},
  'confirm_password': {'fr': 'Confirmer le mot de passe', 'ar': 'تأكيد كلمة المرور'},
  'create_my_account': {'fr': 'Créer mon compte', 'ar': 'إنشاء حسابي'},
  'already_account': {'fr': 'Déjà un compte ? Se connecter', 'ar': 'لديك حساب بالفعل؟ سجّل دخولك'},

  // ── Validation ─────────────────────────────────────────────────────────
  'field_required': {'fr': 'Champ requis', 'ar': 'هذا الحقل مطلوب'},
  'min_3_chars': {'fr': 'Minimum 3 caractères', 'ar': '3 أحرف على الأقل'},
  'min_6_chars': {'fr': 'Minimum 6 caractères', 'ar': '6 أحرف على الأقل'},
  'invalid_email': {'fr': 'Email invalide', 'ar': 'بريد إلكتروني غير صالح'},
  'passwords_differ': {'fr': 'Mots de passe différents', 'ar': 'كلمتا المرور غير متطابقتين'},

  // ── Lobby ───────────────────────────────────────────────────────────────
  'create_room': {'fr': 'Créer une salle', 'ar': 'إنشاء غرفة'},
  'room_name': {'fr': 'Nom de la salle', 'ar': 'اسم الغرفة'},
  'private_room': {'fr': 'Salle privée', 'ar': 'غرفة خاصة'},
  'join_by_code': {'fr': 'Code', 'ar': 'كود'},
  'join_by_code_title': {'fr': 'Rejoindre par code', 'ar': 'الانضمام برمز'},
  'room_code_hint': {'fr': 'ex: AB1234', 'ar': 'مثال: AB1234'},
  'no_rooms': {'fr': 'Aucune salle disponible', 'ar': 'لا توجد غرف متاحة'},
  'refresh': {'fr': 'Actualiser', 'ar': 'تحديث'},
  'play': {'fr': 'Jouer', 'ar': 'العب'},
  'watch': {'fr': 'Voir', 'ar': 'مشاهدة'},
  'cancel': {'fr': 'Annuler', 'ar': 'إلغاء'},
  'create': {'fr': 'Créer', 'ar': 'إنشاء'},
  'join': {'fr': 'Rejoindre', 'ar': 'انضمام'},
  'status_waiting': {'fr': 'Attente', 'ar': 'انتظار'},
  'status_playing': {'fr': 'En cours', 'ar': 'جارٍ'},
  'status_finished': {'fr': 'Terminée', 'ar': 'منتهية'},
  'spectators_count': {'fr': 'spectateurs', 'ar': 'مشاهدون'},

  // ── Room ────────────────────────────────────────────────────────────────
  'room': {'fr': 'Salle', 'ar': 'الغرفة'},
  'copy_code': {'fr': 'Copier le code', 'ar': 'نسخ الرمز'},
  'code_copied': {'fr': 'Code copié !', 'ar': 'تم نسخ الرمز!'},
  'room_code_label': {'fr': 'Code', 'ar': 'الرمز'},
  'position': {'fr': 'Position', 'ar': 'الموضع'},
  'team': {'fr': 'Équipe', 'ar': 'الفريق'},
  'ready_btn': {'fr': 'Je suis prêt', 'ar': 'أنا جاهز'},
  'ready_label': {'fr': 'Prêt !', 'ar': 'جاهز!'},
  'waiting_players': {'fr': 'En attente de joueurs...', 'ar': 'بانتظار اللاعبين...'},
  'waiting_ready': {'fr': 'En attente que tous soient prêts...', 'ar': 'بانتظار أن يكون الجميع جاهزاً...'},
  'spectators_label': {'fr': 'Spectateurs', 'ar': 'المشاهدون'},

  // ── Profile ─────────────────────────────────────────────────────────────
  'profile': {'fr': 'Profil', 'ar': 'الملف الشخصي'},
  'logout': {'fr': 'Déconnexion', 'ar': 'تسجيل الخروج'},
  'username_label': {'fr': 'Nom d\'utilisateur', 'ar': 'اسم المستخدم'},
  'wins': {'fr': 'Victoires', 'ar': 'انتصارات'},
  'losses': {'fr': 'Défaites', 'ar': 'هزائم'},
  'games': {'fr': 'Parties', 'ar': 'مباريات'},
  'win_rate': {'fr': 'Taux de victoire', 'ar': 'نسبة الفوز'},

  // ── Game ────────────────────────────────────────────────────────────────
  'trump_label': {'fr': 'Atout', 'ar': 'الكوز'},
  'trick_empty': {'fr': 'Pli vide', 'ar': 'الطاولة فارغة'},
  'your_turn': {'fr': 'Votre tour !', 'ar': 'دورك!'},
  'tap_again_to_play': {'fr': 'Appuyer à nouveau pour jouer', 'ar': 'اضغط مجدداً للعب'},
  'bidding_wait': {'fr': 'Enchères en cours...', 'ar': 'المزاد جارٍ...'},
  'your_bid_turn': {'fr': 'C\'est votre tour d\'enchérir', 'ar': 'دورك للمزايدة'},
  'turned_card': {'fr': 'Carte retournée', 'ar': 'الورقة المكشوفة'},
  'pass': {'fr': 'Passer', 'ar': 'تمرير'},
  'no_trump': {'fr': 'Sans-atout', 'ar': 'بلا كوز'},
  'choose_trump': {'fr': 'Choisir l\'atout :', 'ar': 'اختر الكوز:'},
  'team1': {'fr': 'Équipe 1', 'ar': 'الفريق 1'},
  'team2': {'fr': 'Équipe 2', 'ar': 'الفريق 2'},
  'round_result': {'fr': 'Résultat du tour', 'ar': 'نتيجة الجولة'},
  'cot_label': {'fr': '🏆 Cot ! Points doublés', 'ar': '🏆 كوت! النقاط مضاعفة'},
  'next_round': {'fr': 'Prochain tour', 'ar': 'الجولة التالية'},
  'match_score': {'fr': 'pts', 'ar': 'نقطة'},
  'game_over': {'fr': 'Partie terminée !', 'ar': 'انتهت اللعبة!'},
  'you_win': {'fr': 'Victoire !', 'ar': 'فزتم!'},
  'you_lose': {'fr': 'Défaite', 'ar': 'خسرتم'},
  'return_lobby': {'fr': 'Retour au lobby', 'ar': 'العودة إلى الردهة'},

  // ── Language toggle ──────────────────────────────────────────────────────
  'language': {'fr': 'Langue', 'ar': 'اللغة'},
};

# Presence Notifier

Usługa obserwuje przejście wybranej osoby ze stanu offline do online na Discordzie
lub Steam. Wtedy pokazuje lokalne powiadomienie i wysyła przez bota Discorda
wiadomość `gramy?`. Pierwszy odczyt wcześniej nieznanego źródła ustala stan
bazowy, więc samo zrestartowanie usługi nie wysyła wiadomości. Jeżeli usługa
pamiętała stan offline, a podczas jej wyłączenia osoba pojawiła się online,
wiadomość zostanie wysłana po następnym uruchomieniu.

## Konfiguracja

1. Utwórz aplikację i bota w Discord Developer Portal.
2. Na stronie bota włącz `Presence Intent`.
3. Dodaj bota na wspólny serwer z obserwowaną osobą. Bot i odbiorca wiadomości
   muszą móc otworzyć prywatną rozmowę.
4. W Discordzie włącz tryb deweloperski. Skopiuj ID wspólnego serwera, ID osoby
   `orixx10` oraz Discord ID każdej osoby, do której aplikacja ma pisać.
5. Utwórz klucz Steam Web API. Najpewniejszy jest 64-bitowy Steam ID. Nazwa
   `Mikuskins` zadziała tylko wtedy, gdy jest nazwą z adresu profilu (vanity URL),
   a nie samą nazwą wyświetlaną. Profil musi udostępniać status publicznie.
6. Po aktywacji konfiguracji skopiuj szablon i uzupełnij sekrety:

   ```sh
   cp ~/.config/presence-notifier/secrets.env.example \
     ~/.config/presence-notifier/secrets.env
   chmod 600 ~/.config/presence-notifier/secrets.env
   presence-notifier --check-config
   systemctl --user start presence-notifier.service
   ```

Logi i zapisany stan można sprawdzić poleceniami:

```sh
journalctl --user -u presence-notifier.service -f
presence-notifier --status
```

`DRY_RUN=true` zachowuje lokalne powiadomienia, ale nie wysyła wiadomości.
Cooldown jest liczony osobno dla każdego odbiorcy. Zapobiega wysłaniu kilku
wiadomości do tej samej osoby, gdy różne platformy zgłoszą jej aktywność lub
status szybko się zmienia. Nie blokuje wiadomości do innych osób.

## Messenger

Messenger Platform jest przeznaczony do rozmów użytkowników ze stronami i
aplikacjami. Nie udostępnia oficjalnego API statusu online prywatnych znajomych.
Dlatego aplikacja nie przechowuje ciasteczek Facebooka i nie skrobie interfejsu
Messengera. Integracja z Gabrielem Skrobolem może zostać dodana dopiero, gdy Meta
udostępni do tego oficjalny mechanizm.

# Редактирование сайта landau.one

Краткая инструкция для редактора. Подробности про инфраструктуру, CI и деплой — в `AGENTS.md` в корне репозитория.

## Один раз перед началом

```bash
brew install hugo                 # extended, актуальный stable
git clone git@github.com:adeepn/landau.git
cd landau
hugo server -D                    # http://localhost:1313, авто-перезагрузка
```

Флаг `-D` показывает черновики (`draft: true`); без него сервер ведёт себя как продакшн и драфты не показывает.

## Базовый цикл

```
правим .md   →   hugo server -D в браузере
git commit && git push origin main   →   CI билдит и rsync на landau.one
```

Деплоится только ветка `main`. Работа в любой другой ветке / PR — без публикации.

## Что и где редактировать

| Что меняем                                | Файл                                            |
| ----------------------------------------- | ----------------------------------------------- |
| Текст главной, контакты, таблицы          | `content/_index.md`                             |
| Конкретное событие                        | `content/events/<slug>/index.md`                |
| Заголовок и описание в шапке сайта        | `hugo.toml` (`title`, `[params].description`)   |
| Цвета, шрифты, отступы                    | `static/css/hacker.css`                         |
| Структура шапки/меню/`<head>`             | `layouts/_default/baseof.html`                  |

Markdown-файлы устроены так: между двумя `---` сверху — YAML-frontmatter (метаданные: title, date, description, draft). Всё ниже — тело страницы.

## Добавить событие

```bash
hugo new content events/open-mic-002/index.md
```

Создаётся файл из шаблона `archetypes/events.md` со структурой 📅 дата / ⏰ время / 📍 формат / 👥 организатор / агенда / регистрация / контакт / бэк-линк.

1. Заполнить тело.
2. Поправить во frontmatter `title`, `description` и `date` (по дате идёт сортировка на `/events/`).
3. Когда готово — `draft: true` → `draft: false`.
4. Локально проверить: `http://localhost:1313/events/open-mic-002/`.
5. `git add content/events/open-mic-002/ && git commit && git push`.

Список всех событий автоматически появится на странице `/events/`. Если нужно, чтобы новое событие отображалось ещё и в секции «🎙️ Список событий» на главной — добавьте ссылку вручную в `content/_index.md` (главная не подтягивает события сама — это сознательно, чтобы вы выбирали что показывать).

## Добавить новость

```bash
hugo new content news/2026-05-06-zagolovok.md
```

Та же логика, шаблон в `archetypes/news.md` проще. Список постов: `/news/`.

## Фото в событие

Событие — это **page bundle**, картинки лежат прямо в его папке рядом с `index.md`:

```
content/events/open-mic-001/
  index.md
  photo-01.jpg
  photo-02.jpg
```

В тексте подключаются обычным markdown:

```markdown
## 📸 Фотоотчёт

![Подпись 1](photo-01.jpg)
![Подпись 2](photo-02.jpg)
```

Hugo сам разрулит относительные пути. Lightbox-галерея с миниатюрами появится, когда накопится десяток фото — попросите.

## Изменить дизайн

Темы как самостоятельной сущности нет: это один CSS-файл `static/css/hacker.css` и четыре маленьких HTML-шаблона в `layouts/`. Большинство правок делается в CSS.

**Сменить акцентный цвет** (зелёный `#b5e853` → бирюзовый `#00d3a5`): find & replace по `hacker.css`. Не забудьте `rgba(...)` со значениями `181, 232, 83` — это тот же цвет в RGB-форме, для `text-shadow` заголовков.

**Изменить максимальную ширину контента** (1000 px → другая): в `hacker.css` поменять `max-width: 1000px;` (`.container`) и условие `@media (max-width: 1000px)` ниже.

**Добавить пункты навигации в шапке**: в `layouts/_default/baseof.html` сразу после `<h2>` дописать

```html
<nav>
  <a href="{{ "/events/" | relURL }}">События</a>
  ·
  <a href="{{ "/news/" | relURL }}">Новости</a>
</nav>
```

и стилизовать через `header nav { ... }` в `hacker.css`.

**Добавить favicon**: положить `static/favicon.ico`, в `<head>` `baseof.html` дописать
`<link rel="icon" href="{{ "/favicon.ico" | relURL }}">`.

## Перед пушем

```bash
hugo --gc --minify
```

Та же команда, что и в CI. Если выходит без warnings и `public/index.html` визуально нормальный — деплой пройдёт.

## Если деплой упал

```bash
gh run list --limit 5
gh run view <ID> --log-failed
```

Типичные причины:

- Секреты `DEPLOY_SSH_*` отсутствуют или с опечаткой → шаг **Deploy via rsync** покажет SSH-ошибку.
- `DEPLOY_SSH_KNOWNHOSTS` устарел (на сервере перевыпустили SSH-ключ) → перегенерировать `ssh-keyscan -t ed25519,rsa <host>` и обновить секрет.
- nginx не отдаёт обновлённое содержимое → проверить, что `DEPLOY_SSH_PATH` действительно равен docroot в nginx-конфиге.

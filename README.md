# Todo Management UI (Hotwire Homework)

แอป Todo หน้าเดียวที่ใช้ Hotwire ครบทุกหัวข้อใน docs บท 6–11 (ไม่รวม Hotwire Native)

```
┌──────────────────────────────────────────────┐
│ Todo Management UI                           │
│ My Tasks                          [3 Tasks]  │
│  3            2            1                 │
│  Total        Todo         Done              │
│ ──────────────────────────────────────────── │
│ Task List                                    │
│ ●  Learn Ruby on Rails                [Todo] │
│ ●  Learn Turbo Streams               [Doing] │
│ ✓  ~~Build Todo App~~                 [Done] │
└──────────────────────────────────────────────┘
```

> **วิธีใช้เอกสารนี้:** อ่าน Step ที่กำลังจะทำก่อน แล้วค่อยลงมือ ทำเสร็จแต่ละ Step ให้เช็คตามหัวข้อ **✅ ตรวจผล** ก่อนไป Step ถัดไป
>
> คำสั่ง `bin/rails` / `yarn` ทุกคำสั่งรันผ่าน `docker compose exec web ...` ขณะที่ `docker compose up` เปิดอยู่

> **เขียนแบบเต็ม ไม่ใช้ shortcut ("Rails magic"):** โค้ดในเอกสารนี้บอกชื่อไฟล์และตัวแปรตรง ๆ ทุกครั้ง อ่านแล้วรู้ทันทีว่ามาจากไหน
>
> | Shortcut (ไม่ใช้) | แบบเต็มที่ใช้ในโปรเจกต์นี้ |
> | --- | --- |
> | `render "form", task: @task` | `render partial: "tasks/form", locals: { task: @task }` |
> | `render @tasks` | `render partial: "tasks/task", collection: @tasks, as: :task` |
> | `form_with model: task` (เดา URL เอง) | `form_with model: task, url: url, method: method` |
> | `turbo_stream.replace @task` | `turbo_stream.replace dom_id(@task), partial: "tasks/task", locals: { task: @task }` |
>
> **partial:** ไฟล์ view ชิ้นเล็กที่ชื่อขึ้นต้นด้วย `_` เวลาเรียกไม่ต้องใส่ `_` และนามสกุล เช่น `"tasks/form"` คือไฟล์ `app/views/tasks/_form.html.erb`

## สารบัญ

| Step | ทำอะไร | หัวข้อใน docs |
| --- | --- | --- |
| [0](#step-0-setup) | Setup | บท 4 |
| [1](#step-1-model-migration-และ-seed) | Model, Migration, Seed | พื้นฐาน Rails |
| [2](#step-2-หน้า-index-ให้เหมือนภาพ) | หน้า index ให้เหมือนภาพ | บท 6 Turbo Drive |
| [3](#step-3-crud-แบบเต็มหน้า) | เพิ่ม / แก้ / ลบแบบเต็มหน้า | บท 6 Form submission rules |
| [4](#step-4-turbo-frames) | ฟอร์มในหน้าเดิม + Edit inline | บท 7 Turbo Frames |
| [5](#step-5-turbo-streams) | อัปเดตหลายจุดพร้อมกัน | บท 8 Turbo Streams |
| [6](#step-6-stimulus) | ล้างฟอร์มหลังเพิ่มงาน | บท 11 Stimulus |
| [7](#step-7-real-time-broadcasting--morphing) | Real-time หลาย browser | บท 9–10 Broadcasting + Morphing |

## Database

มีตารางเดียวคือ `tasks`

| Column | Type | Constraint | หน้าที่ |
| --- | --- | --- | --- |
| `id` | bigint | PK | ใช้สร้าง `dom_id` เช่น `task_1` |
| `title` | string | `null: false` | ชื่องาน |
| `status` | integer | `null: false, default: 0`, index | `0` todo, `1` doing, `2` done |
| `created_at`, `updated_at` | datetime | Rails ใส่ให้ | ใช้เรียงลำดับ |

- ตัวเลขบนหัว (Total / Todo / Done) **ไม่เก็บใน database** แต่นับจาก `status` ทุกครั้ง จึงไม่มีทางไม่ตรงกับข้อมูลจริง
  - **Todo** = งานที่ยังไม่เสร็จ (todo + doing) ในภาพจึงได้ 2
- Database อื่น (`_cable`, `_queue`, `_cache`) Rails สร้างและดูแลเอง ใช้ตอน Step 7

---

## Step 0: Setup

```bash
git clone -b hotwire/workshop --single-branch https://github.com/paradon-sg/BC-Bootcamp.git hotwire-bootcamp
cd hotwire-bootcamp
docker compose up --build
```

> **✅ ตรวจผล:** เปิด http://localhost:3000/up แล้วได้หน้าสีเขียว (status 200)

---

## Step 1: Model, Migration และ Seed

> **🎯 เป้าหมาย:** สร้างตาราง `tasks` และใส่ข้อมูล 3 งานตามภาพ

```bash
docker compose exec web bin/rails generate model Task title:string status:integer
```

แก้ migration ที่ได้ ใส่ `null: false`, `default` และ index:

```ruby
# db/migrate/xxxxxxxxxxxxxx_create_tasks.rb
class CreateTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :tasks do |t|
      t.string  :title,  null: false
      t.integer :status, null: false, default: 0

      t.timestamps
    end

    add_index :tasks, :status
  end
end
```

- `null: false` กันข้อมูลเสียที่ระดับ database แม้มีโค้ดข้าม validation
- index ที่ `status` ช่วยตอนนับสถิติ

```ruby
# app/models/task.rb
class Task < ApplicationRecord
  enum :status, { todo: 0, doing: 1, done: 2 }, default: :todo, validate: true

  validates :title, presence: true

  scope :ordered, -> { order(:created_at, :id) }

  # The status the round button on each row moves the task to.
  def next_status
    case status
    when "todo"  then "doing"
    when "doing" then "done"
    when "done"  then "todo"
    end
  end
end
```

- **`enum`:** database เก็บตัวเลข แต่ในโค้ดเรียกเป็นชื่อได้ เช่น `task.done?`, `Task.todo`
  - ห้ามเปลี่ยนตัวเลขของสถานะที่มีอยู่แล้ว ข้อมูลเดิมจะเปลี่ยนความหมาย
  - `validate: true` ทำให้ค่าแปลก ๆ จากฟอร์มเป็น validation error ไม่ใช่ error 500
- **`next_status`:** ใช้กับปุ่มวงกลมใน Step 5

```ruby
# db/seeds.rb
[
  { title: "Learn Ruby on Rails", status: :todo },
  { title: "Learn Turbo Streams", status: :doing },
  { title: "Build Todo App",      status: :done }
].each do |attrs|
  Task.find_or_create_by!(title: attrs[:title]) { |task| task.status = attrs[:status] }
end
```

```bash
docker compose exec web bin/rails db:migrate
docker compose exec web bin/rails db:seed
```

- `find_or_create_by!` สร้างเฉพาะงานที่ยังไม่มี รัน seed ซ้ำได้ไม่ซ้ำ

> **✅ ตรวจผล:** `docker compose exec web bin/rails console`
>
> - `Task.count` ได้ `3`
> - `Task.new.valid?` ได้ `false` (ไม่มีชื่อ)
> - `Task.new.status` ได้ `"todo"`

---

## Step 2: หน้า index ให้เหมือนภาพ

> **🎯 เป้าหมาย:** หน้า `/` แสดงการ์ด My Tasks, สถิติ และรายการงาน
>
> **Turbo Drive (บท 6):** ได้มาฟรีเพราะ `application.js` import `@hotwired/turbo-rails` อยู่แล้ว ลิงก์และฟอร์มทุกอันจะเปลี่ยนหน้าแบบไม่กระพริบ

**สร้าง controller ด้วย generator:**

```bash
docker compose exec web bin/rails generate controller Tasks index --skip-routes
```

| ไฟล์ที่ได้ | ข้างใน |
| --- | --- |
| `app/controllers/tasks_controller.rb` | `TasksController` ที่มี `def index` ว่าง ๆ |
| `app/views/tasks/index.html.erb` | หน้าตัวอย่าง (ลบเนื้อหาแล้วใส่ของเราแทน) |
| `app/helpers/tasks_helper.rb` | `module TasksHelper` ว่าง ๆ |

- **ชื่อเป็นพหูพจน์ (`Tasks`):** ได้ `TasksController` ซึ่งตรงกับ `resources :tasks`
- **`--skip-routes`:** ไม่ให้ generator เพิ่ม `get "tasks/index"` ลงใน routes เพราะเราเขียน routes เอง (ถ้าลืมใส่ ให้ลบบรรทัดนั้นออก)
- **ใส่แค่ `index`:** action อื่นค่อยเพิ่มใน Step 3 ถ้าใส่ตอนนี้จะได้ view ว่าง ๆ ที่ยังไม่ได้ใช้

ไฟล์ที่เหลือใน Step นี้ไม่มี generator ต้องแก้หรือสร้างเอง: `config/routes.rb`, layout, `_summary.html.erb`, `_task.html.erb` และ CSS

```ruby
# config/routes.rb
Rails.application.routes.draw do
  resources :tasks, except: :show

  get "up" => "rails/health#show", as: :rails_health_check

  root "tasks#index"
end
```

```ruby
# app/controllers/tasks_controller.rb (เติมใน index ที่ generator สร้างไว้)
class TasksController < ApplicationController
  def index
    @tasks = Task.ordered
  end
end
```

**Helper** (เติมใน module ที่ generator สร้างไว้): นับสถิติ, ไอคอน และ pill ตามสถานะ

```ruby
# app/helpers/tasks_helper.rb
module TasksHelper
  PILL_CLASSES = {
    "todo"  => "bg-gray-100 text-gray-800",
    "doing" => "bg-gray-100 text-gray-800",
    "done"  => "bg-green-100 text-green-700"
  }.freeze

  # { total: 3, todo: 2, done: 1 } — "todo" counts every unfinished task (todo + doing).
  def task_stats
    counts = Task.group(:status).count
    total  = counts.values.sum
    done   = counts.fetch("done", 0)
    { total: total, todo: total - done, done: done }
  end

  def status_pill(task)
    tag.span task.status.humanize, class: "pill #{PILL_CLASSES.fetch(task.status)}"
  end

  def status_icon(task)
    if task.done?
      tag.span "✓", class: "flex size-6 items-center justify-center rounded-full border-2 border-green-700 text-xs font-bold text-green-700"
    else
      tag.span class: "block size-6 rounded-full bg-gray-600"
    end
  end
end
```

**Layout:** เปลี่ยน stylesheet และเพิ่ม flash

```erb
<%# app/views/layouts/application.html.erb (เฉพาะส่วนที่เปลี่ยน) %>
<%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>

<body class="min-h-screen bg-gray-50 text-gray-900">
  <main class="mx-auto max-w-3xl px-4 py-10">
    <% flash.each do |type, message| %>
      <p role="<%= type == "alert" ? "alert" : "status" %>" data-turbo-temporary
         class="mb-6 rounded-lg border bg-white px-4 py-3 text-sm"><%= message %></p>
    <% end %>

    <%= yield %>
  </main>
</body>
```

- **`"application"` แทน `:app`:** โหลดเฉพาะ CSS ที่ Tailwind build แล้ว (`app/assets/builds/application.css`)
- **`data-turbo-temporary`:** Turbo ไม่เก็บ flash ไว้ใน cache จึงไม่โผล่ซ้ำตอนกด Back (บท 6 Cache)

**View:**

```erb
<%# app/views/tasks/index.html.erb (ลบของเดิมที่ generator ใส่มาทั้งหมด) %>
<% content_for :title, "My Tasks" %>

<div class="rounded-2xl border bg-white p-6">
  <p class="text-lg font-medium">Todo Management UI</p>

  <div id="task_summary"><%= render partial: "tasks/summary" %></div>

  <hr class="my-6">

  <h3 class="mb-3 text-lg font-medium">Task List</h3>
  <div id="tasks" class="flex flex-col gap-1">
    <%= render partial: "tasks/task", collection: @tasks, as: :task %>
  </div>
</div>
```

```erb
<%# app/views/tasks/_summary.html.erb (สร้างไฟล์ใหม่) %>
<% stats = task_stats %>
<div class="mt-4 flex items-center justify-between">
  <h2 class="text-2xl font-semibold">My Tasks</h2>
  <span class="pill bg-green-100 text-green-700"><%= pluralize(stats[:total], "Task") %></span>
</div>

<dl class="mt-6 grid grid-cols-3">
  <% { "Total" => stats[:total], "Todo" => stats[:todo], "Done" => stats[:done] }.each do |label, count| %>
    <div class="flex flex-col-reverse gap-2 px-4">
      <dt class="text-gray-500"><%= label %></dt>
      <dd class="text-3xl font-semibold"><%= count %></dd>
    </div>
  <% end %>
</dl>
```

- `flex-col-reverse` ให้ตัวเลขอยู่บน label อยู่ล่างตามภาพ แต่ใน HTML `<dt>` (หัวข้อ) ยังมาก่อน `<dd>` (ค่า) ตามหลัก

```erb
<%# app/views/tasks/_task.html.erb (สร้างไฟล์ใหม่) %>
<div id="<%= dom_id(task) %>" class="flex items-center gap-3 py-2">
  <%= status_icon(task) %>
  <span class="flex-1 text-lg <%= "line-through" if task.done? %>"><%= task.title %></span>
  <%= status_pill(task) %>
</div>
```

- **`id="task_summary"`** อยู่ใน index ส่วน partial มีแค่เนื้อหาข้างใน เพราะ Step 5 จะใช้ stream `update` แทนที่เฉพาะข้างใน
- **`id="tasks"`** เป็นที่ที่ Step 5 `append` งานใหม่ต่อท้าย
- **`render partial: "tasks/task", collection: @tasks, as: :task`** render ไฟล์ `app/views/tasks/_task.html.erb` ทีละงานใน `@tasks`
  - `as: :task` = ข้างใน `_task` เรียกงานแต่ละอันด้วยตัวแปรชื่อ `task`
- **`render partial: "tasks/summary"`** render ไฟล์ `app/views/tasks/_summary.html.erb` ครั้งเดียว

**CSS:**

```css
/* app/assets/stylesheets/application.tailwind.css */
@import "tailwindcss";

@layer components {
  .btn        { @apply inline-flex cursor-pointer items-center rounded-lg border bg-white px-3 py-1.5 text-sm hover:bg-gray-50; }
  .pill       { @apply rounded-full px-3 py-1 text-sm; }
  .form-label { @apply mb-1 block text-sm; }
  .form-input { @apply block w-full rounded-lg border px-3 py-2 text-sm; }
  .field_with_errors { display: contents; }
}
```

> **✅ ตรวจผล:** เปิด http://localhost:3000 แล้วควรเห็น
>
> - การ์ด "My Tasks" กับ badge "3 Tasks"
> - สถิติ 3 / 2 / 1 (Total / Todo / Done)
> - งาน 3 แถว: วงกลมเทา + pill Todo, วงกลมเทา + pill Doing, ติ๊กเขียว + ชื่อขีดฆ่า + pill Done สีเขียว
>
> ถ้าหน้าไม่มีสี ให้ดู log ของ `docker compose up` ว่า process `css` build ผ่านหรือเปล่า

---

## Step 3: CRUD แบบเต็มหน้า

> **🎯 เป้าหมาย:** เพิ่ม / แก้ / ลบงานได้ และทำตาม **Form submission rules** ของ Turbo (บท 6)
>
> | ผล | ต้องตอบ |
> | --- | --- |
> | บันทึกสำเร็จ | `redirect_to` |
> | validation ไม่ผ่าน | `render` + `status: :unprocessable_entity` (422) |
> | หลัง DELETE | `redirect_to ..., status: :see_other` (303) |

```ruby
# app/controllers/tasks_controller.rb
class TasksController < ApplicationController
  before_action :set_task, only: %i[edit update destroy]

  def index
    @tasks = Task.ordered
  end

  def new
    @task = Task.new
  end

  def edit
  end

  def create
    @task = Task.new(task_params)
    if @task.save
      redirect_to tasks_path, notice: "Task created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @task.update(task_params)
      redirect_to tasks_path, notice: "Task updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @task.destroy!
    redirect_to tasks_path, notice: "Task deleted.", status: :see_other
  end

  private

  def set_task
    @task = Task.find(params[:id])
  end

  def task_params
    params.require(:task).permit(:title, :status)
  end
end
```

- ถ้าลืม 422 Turbo จะไม่ render ฟอร์มที่มี error
- ถ้าลืม 303 browser อาจส่ง DELETE ซ้ำตอนตาม redirect
- `task_params` permit เฉพาะ `title`, `status` (strong parameters)

```erb
<%# app/views/tasks/_form.html.erb %>
<%# New task → POST /tasks (create). Existing task → PATCH /tasks/:id (update). %>
<% url    = task.new_record? ? tasks_path : task_path(task) %>
<% method = task.new_record? ? :post : :patch %>

<%# model: fills the fields with task's values and names them task[title], task[status]. %>
<%= form_with model: task, url: url, method: method, class: "space-y-4" do |form| %>
  <% if task.errors.any? %>
    <div role="alert" class="rounded-lg border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
      <% task.errors.full_messages.each do |message| %>
        <p><%= message %></p>
      <% end %>
    </div>
  <% end %>

  <div>
    <%= form.label :title, class: "form-label" %>
    <%= form.text_field :title, class: "form-input", autofocus: true %>
  </div>

  <div>
    <%= form.label :status, class: "form-label" %>
    <%= form.select :status, Task.statuses.keys.map { |s| [ s.humanize, s ] }, {}, class: "form-input" %>
  </div>

  <div class="flex justify-end gap-2">
    <%= link_to "Cancel", tasks_path, class: "btn" %>
    <%= form.submit task.new_record? ? "Add task" : "Save", class: "btn",
          data: { turbo_submits_with: "Saving..." } %>
  </div>
<% end %>
```

- **ฟอร์มเดียวใช้ทั้ง New และ Edit:** `task.new_record?` เป็น `true` เมื่อยังไม่เคยบันทึก (มาจาก `new`)
  | มาจาก | `url` | `method` | ไปที่ controller |
  | --- | --- | --- | --- |
  | New | `/tasks` | POST | `TasksController#create` |
  | Edit | `/tasks/1` | PATCH | `TasksController#update` |
- **`model: task`:** ใช้เติมค่าเดิมลงช่องกรอก และตั้งชื่อช่องเป็น `task[title]`, `task[status]` ให้ตรงกับ `params.require(:task)` ใน controller
- **ปุ่ม submit:** ข้อความเป็น "Add task" หรือ "Save" ตาม `task.new_record?`
- **`turbo_submits_with`:** ระหว่าง submit ปุ่มเปลี่ยนเป็น "Saving..." และถูก disable

```erb
<%# app/views/tasks/new.html.erb (edit.html.erb เหมือนกัน เปลี่ยนหัวข้อเป็น "Edit task") %>
<% content_for :title, "New task" %>

<div class="rounded-2xl border bg-white p-6">
  <h1 class="mb-4 text-xl font-semibold">New task</h1>
  <%= render partial: "tasks/form", locals: { task: @task } %>
</div>
```

เพิ่มลิงก์และปุ่มในหน้า index / แถว:

```erb
<%# index.html.erb: เหนือรายการงาน %>
<div class="mb-3 flex items-center justify-between">
  <h3 class="text-lg font-medium">Task List</h3>
  <%= link_to "+ New task", new_task_path, class: "btn" %>
</div>

<%# _task.html.erb: ต่อจาก status_pill %>
<%= link_to "Edit", edit_task_path(task), class: "text-sm underline" %>
<%= button_to "Delete", task_path(task), method: :delete, class: "cursor-pointer text-sm text-red-600",
      form: { data: { turbo_confirm: "Delete \"#{task.title}\"?" } } %>
```

- **`button_to ... method: :delete`:** ลิงก์ปกติส่งได้แค่ GET การลบจึงใช้ฟอร์ม (บท 6 Link ที่ใช้ HTTP method อื่น)
  - ห้ามใช้ GET สำหรับการลบ เพราะ Turbo prefetch ตอน hover อาจลบข้อมูลโดยไม่ตั้งใจ
- **`turbo_confirm`** อยู่ที่ `<form>` Turbo ถามยืนยันก่อนส่ง

> **✅ ตรวจผล:**
>
> - เพิ่มงานโดยเว้นชื่อว่าง → เห็น "Title can't be blank"
> - เพิ่ม / แก้ / ลบงานได้ ลบแล้วมีกล่องยืนยัน
> - เปลี่ยนหน้าแล้วไม่กระพริบขาว
> - กด Back ของ browser แล้วข้อความ flash ไม่กลับมา

---

## Step 4: Turbo Frames

> **🎯 เป้าหมาย:** ไม่ต้องเปลี่ยนหน้าอีกต่อไป
>
> - กด "+ New task" แล้วฟอร์มโผล่ **ในหน้าเดิม**
> - กด Edit แล้วแถวนั้นกลายเป็นฟอร์ม **แก้ในแถวได้เลย**
>
> **หลักการ (บท 7):** Turbo หา `<turbo-frame>` ที่ **id เดียวกัน** ใน response แล้วเปลี่ยนเฉพาะ frame นั้น ส่วนอื่นของหน้าไม่ขยับ

**1) ฟอร์มเพิ่มงาน: ควบคุม frame จากภายนอก**

```erb
<%# index.html.erb %>
<%= link_to "+ New task", new_task_path, class: "btn", data: { turbo_frame: "new_task" } %>

<%= turbo_frame_tag "new_task", class: "mb-4 block" %>   <%# ว่างไว้ รอรับฟอร์ม %>

<div id="tasks" class="flex flex-col gap-1">
  <%= render partial: "tasks/task", collection: @tasks, as: :task %>
</div>
```

```erb
<%# new.html.erb: ห่อฟอร์มด้วย frame id เดียวกัน %>
<%= turbo_frame_tag "new_task" do %>
  <%= render partial: "tasks/form", locals: { task: @task } %>
<% end %>
```

- ลิงก์อยู่**นอก** frame แต่ `data-turbo-frame="new_task"` สั่งให้ไปเปลี่ยน frame นั้น

**2) Edit inline: frame ต่อแถว**

```erb
<%# _task.html.erb: ห่อทั้งแถว (ลบ id ออกจาก div เพราะ frame มี id แทนแล้ว) %>
<%= turbo_frame_tag dom_id(task) do %>
  <div class="flex items-center gap-3 py-2">
    ... เหมือนเดิม ...
  </div>
<% end %>
```

```erb
<%# edit.html.erb: ห่อฟอร์มด้วย frame id ของงานนั้น %>
<%= turbo_frame_tag dom_id(@task) do %>
  <%= render partial: "tasks/form", locals: { task: @task } %>
<% end %>
```

- `turbo_frame_tag dom_id(task)` สร้าง `<turbo-frame id="task_1">`
- ลิงก์ Edit อยู่**ใน** frame จึงโหลดฟอร์มมาแทนแถวนั้นเอง
- **Cancel** (`link_to tasks_path`) ใน frame จะโหลดหน้า index แล้วหยิบ frame id เดียวกันกลับมา จึงกลับเป็นแถวเดิมหรือ frame ว่างโดยไม่ต้องเขียนอะไรเพิ่ม
- ถ้า id ไม่ตรงกัน จะเห็น **"Content missing"**

**3) Delete: Breaking out ออกจาก frame**

```erb
<%# _task.html.erb %>
<%= button_to "Delete", task_path(task), method: :delete,
      form: { data: { turbo_confirm: "Delete \"#{task.title}\"?", turbo_frame: "_top" } } %>
```

- ปุ่ม Delete อยู่ใน frame `task_1` ถ้าไม่ใส่อะไร Turbo จะหา `task_1` ใน response แต่งานถูกลบไปแล้ว เลยเจอ **"Content missing"**
- `turbo_frame: "_top"` บอกให้เปลี่ยนทั้งหน้าแทน (บท 7 Navigate ออกนอก frame)

> **⚠️ สิ่งที่จะเจอ (ตั้งใจ):**
>
> - เพิ่มงานใหม่สำเร็จ แต่**ไม่โผล่ในรายการ** จนกว่าจะ refresh
> - เปลี่ยนสถานะในฟอร์ม Edit แล้ว**ตัวเลขสถิติไม่เปลี่ยน**
>
> เพราะ Frame เปลี่ยนได้ **ทีละกล่องเท่านั้น** การอัปเดตหลายจุดพร้อมกันคือหน้าที่ของ **Turbo Streams** ใน Step 5

> **✅ ตรวจผล:**
>
> - กด "+ New task" ฟอร์มโผล่ในหน้าเดิม URL ไม่เปลี่ยน
> - กด Edit แถวนั้นเป็นฟอร์ม แถวอื่นไม่ขยับ กด Cancel กลับเป็นแถวเดิม
> - ส่งชื่อว่างใน frame แล้วเห็น error ในกรอบนั้น (เพราะตอบ 422)

---

## Step 5: Turbo Streams

> **🎯 เป้าหมาย:** ทำครั้งเดียวแล้วอัปเดต **หลายจุด** พร้อมกัน และเพิ่มปุ่มวงกลมเปลี่ยนสถานะ
>
> **Turbo Stream = ใบสั่งงาน (บท 8):** แต่ละข้อบอกว่า **ทำอะไร** (action) กับ **element id ไหน** (target)

| ทำอะไร | ใบสั่งงานที่ตอบกลับ |
| --- | --- |
| เพิ่มงาน | `append` แถวใหม่เข้า `#tasks` + `update` `#task_summary` |
| เปลี่ยนสถานะ / แก้ inline | `replace` แถวนั้น + `update` `#task_summary` |
| ลบ | `remove` แถวนั้น + `update` `#task_summary` |

**Controller:** ตอบ stream ถ้ามาจาก Turbo และ redirect ถ้าไม่ใช่ (`format.html` fallback)

```ruby
def create
  @task = Task.new(task_params)
  if @task.save
    respond_to do |format|
      format.turbo_stream { render :create }  # create.turbo_stream.erb
      format.html { redirect_to tasks_path, notice: "Task created." }
    end
  else
    render :new, status: :unprocessable_entity
  end
end

def update
  if @task.update(task_params)
    respond_to do |format|
      format.turbo_stream { render :update }  # update.turbo_stream.erb
      format.html { redirect_to tasks_path, notice: "Task updated." }
    end
  else
    render :edit, status: :unprocessable_entity
  end
end

def destroy
  @task.destroy!
  respond_to do |format|
    format.turbo_stream { render :destroy } # destroy.turbo_stream.erb
    format.html { redirect_to tasks_path, notice: "Task deleted.", status: :see_other }
  end
end
```

- Turbo ใส่ `text/vnd.turbo-stream.html` ใน `Accept` header ให้เองตอน submit ฟอร์มที่ไม่ใช่ GET `format.turbo_stream` จึงทำงาน

**Template ของใบสั่งงาน:**

```erb
<%# app/views/tasks/create.turbo_stream.erb %>
<%= turbo_stream.append "tasks", partial: "tasks/task", locals: { task: @task } %>
<%= turbo_stream.update "task_summary", partial: "tasks/summary" %>
```

```erb
<%# app/views/tasks/update.turbo_stream.erb %>
<%= turbo_stream.replace dom_id(@task), partial: "tasks/task", locals: { task: @task } %>
<%= turbo_stream.update "task_summary", partial: "tasks/summary" %>
```

```erb
<%# app/views/tasks/destroy.turbo_stream.erb %>
<%= turbo_stream.remove dom_id(@task) %>
<%= turbo_stream.update "task_summary", partial: "tasks/summary" %>
```

- **`append "tasks", partial: "tasks/task", locals: { task: @task }`** render `_task.html.erb` ของงานใหม่ แล้วต่อท้าย `<div id="tasks">`
- **`replace dom_id(@task), partial: ...`** หา element `task_1` แล้วแทนทั้งก้อนด้วย `_task` ใหม่ (แถวกลับมาจากฟอร์ม Edit ด้วย)
- **`remove dom_id(@task)`** ลบ element `task_1` ออก
- **`update` vs `replace`:** `update` เปลี่ยนแค่**ข้างใน** `#task_summary` ตัว div ยังอยู่ จึงอัปเดตซ้ำได้เรื่อย ๆ

**ปุ่มวงกลมเปลี่ยนสถานะ:** เปลี่ยน `status_icon` ใน `_task` เป็นปุ่ม

```erb
<%= button_to task_path(task), method: :patch,
      params: { task: { status: task.next_status } },
      class: "cursor-pointer", title: "Mark as #{task.next_status.humanize}" do %>
  <%= status_icon(task) %>
<% end %>
```

- สร้างฟอร์ม `PATCH /tasks/1` พร้อม hidden field `task[status]=doing` ไปที่ `update` ตัวเดิม ไม่ต้องมี route ใหม่

> **✅ ตรวจผล:**
>
> - กดวงกลม: Todo → Doing → Done (ติ๊กถูก + ขีดฆ่า) → Todo ตัวเลขสถิติและ badge เปลี่ยนทันที
> - เพิ่มงานใหม่แล้วโผล่ท้ายรายการ, ลบแล้วหายไป หน้าไม่ reload
> - DevTools (F12) → Network → กดปุ่มอีกครั้ง → response มี `<turbo-stream action="replace">` และ `<turbo-stream action="update">`

---

## Step 6: Stimulus

> **🎯 เป้าหมาย:** เพิ่มงานสำเร็จแล้ว **ฟอร์มล้างตัวเอง** พร้อมกรอกงานถัดไป
>
> **ทำไมต้อง Stimulus (บท 11):** เป็นงานเล็ก ๆ ฝั่ง browser ไม่ต้องคุยกับ server เพิ่ม

```bash
rm app/javascript/controllers/hello_controller.js
docker compose exec web bin/rails generate stimulus reset_form
```

- generator สร้างไฟล์และ register ใน `controllers/index.js` ให้ (ลบ `hello` ออกด้วย `bin/rails stimulus:manifest:update`)

```js
// app/javascript/controllers/reset_form_controller.js
import { Controller } from "@hotwired/stimulus"

// Clears the form after a successful Turbo submit.
// <form data-controller="reset-form" data-action="turbo:submit-end->reset-form#reset">
export default class extends Controller {
  static targets = ["errors"]

  reset(event) {
    if (!event.detail.success) return

    this.element.reset()
    this.errorsTargets.forEach((element) => element.remove())
  }
}
```

ใส่ที่ฟอร์ม **เฉพาะตอนเพิ่มงานใหม่**:

```erb
<%# _form.html.erb %>
<% url    = task.new_record? ? tasks_path : task_path(task) %>
<% method = task.new_record? ? :post : :patch %>
<%# Only the new-task form clears itself after saving. %>
<% data   = task.new_record? ? { controller: "reset-form", action: "turbo:submit-end->reset-form#reset" } : {} %>

<%= form_with model: task, url: url, method: method, data: data, class: "space-y-4" do |form| %>

  <% if task.errors.any? %>
    <div role="alert" data-reset-form-target="errors" class="...">
```

**อ่าน data attribute ยังไง:**

| Attribute | ความหมาย |
| --- | --- |
| `data-controller="reset-form"` | ฟอร์มนี้ใช้ `reset_form_controller.js` (`this.element` = `<form>`) |
| `data-action="turbo:submit-end->reset-form#reset"` | เมื่อ Turbo submit เสร็จ ให้เรียก `reset()` |
| `data-reset-form-target="errors"` | กล่อง error ที่ controller หยิบไปลบได้ (`this.errorsTargets`) |

- `event.detail.success` เป็น `true` เมื่อ server ตอบ 2xx ถ้า validation ไม่ผ่าน (422) จะไม่ล้างฟอร์ม
- ไม่ใช้ `document.querySelector` / `DOMContentLoaded` เพราะ Turbo ไม่ reload หน้า Stimulus จะ `connect()` ให้ใหม่ทุกครั้งที่ element โผล่

> **✅ ตรวจผล:**
>
> - เพิ่มงานสำเร็จ → ช่อง Title ว่าง พิมพ์งานถัดไปได้เลย
> - ส่งชื่อว่างแล้วเห็น error จากนั้นส่งชื่อที่ถูก → error หายและฟอร์มว่าง
> - ไปหน้าอื่นแล้วกลับมา ก็ยังทำงาน

---

## Step 7: Real-time (Broadcasting + Morphing)

> **🎯 เป้าหมาย:** เปิด 2 browser แล้วเห็นการเปลี่ยนแปลงของอีกฝั่งทันที
>
> - **Broadcasting (บท 9):** เหมือนกลุ่มแชท Model ส่งข้อความเข้ากลุ่ม `"tasks"` ทุกหน้าที่ subscribe กลุ่มนี้ได้รับ
> - **Morphing (บท 10):** ข้อความคือ `refresh` แต่ละ browser โหลดหน้าตัวเองใหม่ แล้วแก้**เฉพาะจุดที่ต่าง** scroll ไม่เด้ง

**1) เปิด morph ทั้งเว็บ** (ต้องอยู่**ก่อน** `yield :head` เพราะ helper ใส่ meta ผ่าน `content_for :head`)

```erb
<%# app/views/layouts/application.html.erb %>
<%= turbo_refreshes_with method: :morph, scroll: :preserve %>
<%= yield :head %>
```

**2) Model ส่งข้อความเมื่อข้อมูลเปลี่ยน**

```ruby
# app/models/task.rb
class Task < ApplicationRecord
  # ... enum / validates / scope เหมือน Step 1

  # Live updates: every change tells pages subscribed to "tasks" to refresh (morph).
  after_create_commit  -> { broadcast_refresh_later_to "tasks" }
  after_update_commit  -> { broadcast_refresh_later_to "tasks" }
  after_destroy_commit -> { broadcast_refresh_to "tasks" }
end
```

- **`_later`:** ส่งผ่าน background job (process `worker` ใน `bin/dev`) ไม่ทำให้ request ช้า
- **destroy ไม่ใช้ `_later`:** record ถูกลบไปแล้ว job จะหาไม่เจอ

**3) View subscribe กลุ่ม**

```erb
<%# index.html.erb บรรทัดแรก ๆ %>
<%= turbo_stream_from "tasks" %>
```

- ชื่อกลุ่มทั้งสองฝั่งต้องตรงกัน (`"tasks"`)
- คนที่กดเองได้ผลจาก Step 5 แล้ว Turbo จะข้าม refresh ที่มาจาก request ของตัวเอง

> **Security:** แอปนี้ไม่มีระบบ login ทุกคนที่เปิดหน้าเห็นและแก้งานได้หมด ในงานจริงต้องเพิ่ม authentication และ scope stream ตามผู้ใช้ เช่น `turbo_stream_from Current.user, "tasks"`

> **✅ ตรวจผล:**
>
> - เปิด http://localhost:3000 ใน 2 browser (หรือ 1 หน้าต่างปกติ + 1 Incognito)
> - เพิ่ม / แก้ / ลบ / กดวงกลมฝั่งหนึ่ง → อีกฝั่งอัปเดตเองภายในไม่กี่วินาที ตัวเลขสถิติตรงกัน
> - ถ้าไม่อัปเดต: เช็คว่ามี `turbo_stream_from "tasks"` และ log ของ `docker compose up` มี process `worker` ทำงาน

---

## สรุปเทียบกับ docs

| หัวข้อใน docs | ใช้ที่ไหน |
| --- | --- |
| Turbo Drive: เปลี่ยนหน้าไม่กระพริบ, Form rules (422 / 303), method อื่น + `turbo_confirm`, `turbo_submits_with`, Cache (`data-turbo-temporary`) | Step 2–3 |
| Turbo Frames: frame ต่อแถว, ควบคุม frame จากภายนอก, Cancel กลับแถวเดิม | Step 4 |
| Turbo Streams: `append` / `replace` / `remove` / `update` หลาย action ต่อ response, `format.html` fallback | Step 5 |
| Stimulus: controller, action, target, ฟัง Turbo event, `connect` หลังเปลี่ยนหน้า | Step 6 |
| Broadcasting: `turbo_stream_from` + `broadcast_refresh_later_to` | Step 7 |
| Page Refresh & Morphing: `turbo_refreshes_with method: :morph, scroll: :preserve` | Step 7 |
| Hotwire Native | ไม่ทำ |

## ตรวจรวมก่อนส่ง

```bash
docker compose exec web bin/rubocop
```

- ไล่ **✅ ตรวจผล** ทุก Step อีกรอบ
- ไม่มี secret / รหัสผ่าน hardcode ในโค้ด (database ใช้ `DATABASE_URL` จาก `compose.yml`)

---

## Deploy บน Render (Blueprint)

ไฟล์ `render.yaml` บอก Render ว่าต้องสร้างอะไรบ้าง กดครั้งเดียวได้ทั้ง database และเว็บ

| สร้างอะไร | รายละเอียด |
| --- | --- |
| Postgres `hotwire-todo-db` | แบบฟรี, Singapore |
| Web service `hotwire-todo` | build จาก `Dockerfile` (production), แบบฟรี, Singapore, branch `main` |

**Environment variables (ตั้งให้อัตโนมัติ ไม่มี secret อยู่ในไฟล์)**

| Key | มาจาก | ทำไม |
| --- | --- | --- |
| `DATABASE_URL` | database ที่ Blueprint สร้าง | database เดียวของแอป |
| `SECRET_KEY_BASE` | Render สุ่มให้ (`generateValue`) | production ต้องมีกุญแจลับ (repo ไม่มี `master.key`) |
| `SOLID_QUEUE_IN_PUMA` | `true` | บน Render ไม่มี process `worker` แยก ให้ Puma รัน job เอง (broadcast `_later` ใน Step 7) |
| `PORT` | `80` | Dockerfile เปิด Thruster ที่ port 80 แล้ว Thruster รัน Puma ที่ 3000 อยู่ข้างหลัง |

**Database เดียว:** ตาราง Solid Queue / Cache / Cable อยู่ใน database เดียวกับ `tasks` (migration `create_solid_tables`) ตามวิธี "Single database configuration" ของ Solid Queue เพราะ Render ฟรีให้ Postgres ได้ 1 ตัว

**ขั้นตอน**

1. Render → **New → Blueprint** → เลือก repo `hotwire-todo`, branch `main`
2. กด **Deploy Blueprint** แล้วรอ build (ครั้งแรก 5–10 นาที)
3. ตอน start `bin/docker-entrypoint` รัน `db:prepare` สร้างตารางให้เอง
4. เปิด URL `https://hotwire-todo-xxxx.onrender.com` (database ใหม่ยังไม่มีงาน เพิ่มเองจากหน้าเว็บ)

> **ข้อจำกัดแบบฟรี:** เว็บหลับเมื่อไม่มีคนใช้ (เปิดครั้งแรกรอประมาณ 1 นาที) และ Render ให้ Postgres ฟรีได้ 1 ตัวต่อ workspace

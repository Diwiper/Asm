;формування і виведення на екран графіка функції y=0,7*x^2+5,7*x+1
.386

; Визначення макросу для обчислення масштабу
scale   macro   p1
    fld max_&p1         ; завантажуємо максимальне значення по осі p1
    fsub min_&p1        ; віднімаємо мінімальне значення
    fild max_crt_&p1    ; завантажуємо максимальну кількість точок по осі p1
    fdivp st(1), st(0)  ; ділимо для отримання масштабу
    fstp scale_&p1      ; зберігаємо масштаб
endm

STACK_SEG SEGMENT STACK use16
    DW  1000 DUP (?)
STACK_SEG ENDS 

; Визначаємо кольори для різних функцій
poly_color    equ     0Eh     ; Жовтий для основної функції
x2_color      equ     0Ch     ; Червоний для x^2 компоненти
x_color       equ     0Ah     ; Зелений для x компоненти
xy_color      equ     0Dh     ; Рожевий для y=x
const_color   equ     09h     ; Голубий для константи
axis_color    equ     0Fh     ; Білий для осей
out_of_range  equ     0       ; Значення для точок поза екраном (0 = не виводити)

DATA_SEG SEGMENT use16
    max_crt_x   dw     320        ; Максимальна кількість точок по X                                 
    max_crt_y   dw     200        ; Максимальна кількість точок по Y

    min_x       dq   (-20.0)      ; Мінімальне значення по осі X
    max_x       dq   (10.0)       ; Максимальне значення по осі X
    crt_x       dw	(?)	     ; Eкранна координата по осі X
    scale_x     dq	(?)	     ; Масштаб по осі X
    x_value     dq   (?)          ; Поточне значення X
    
    x_step      dq   (0.001)       ; Приріст по осі X
    max_x_steps dw   (?)          ; Кількість кроків по осі X

    min_y       dq   (-12.0)      ; Мінімальне значення по осі Y
    max_y       dq   (80.0)       ; Максимальне значення по осі Y
    crt_y       dw	(?)	     ; Eкранна координата по осі Y
    scale_y     dq 	(?)         ; Масштаб по осі Y
    y_value     dq   (?)          ; Поточне значення Y

    ; Константи для 0,7*x^2+5,7*x+1
    coef_x2     dq   (0.7)        ; Коефіцієнт при x^2
    coef_x      dq   (5.7)        ; Коефіцієнт при x
    coef_const  dq   (1.0)        ; Константа

    print_color dw   (?)          ; Колір, яким малюємо точку
    tmp         dw   (?)          ; Тимчасова змінна
    point_valid db   (?)          ; Прапорець валідності точки (1 - валідна, 0 - невалідна)

DATA_SEG ENDS

CODE_SEG SEGMENT use16
ASSUME CS:CODE_SEG, DS:DATA_SEG    

; Процедура для виведення точки на екран
output_pixel proc near
    push bp         ; Збереження стану регістрів
    mov bp, sp
    pusha
    push es

        push 0a000h     ; Адреса відео пам'яті в графічному режимі 
        pop es
        
        mov cx, [bp + 8] ; x
        mov dx, [bp + 6] ; y
        mov ax, [bp + 4] ; color

        ; Якщо колір дорівнює out_of_range (0), не малюємо точку
        or ax, ax
        jz skip_point
        
        ; Перевірка чи точка в межах екрану
        cmp cx, 320
        jae skip_point
        cmp dx, 200
        jae skip_point

        mov bx, dx
        shl bx, 8   ; *256
        shl dx, 6   ; *64
        add bx, dx
        add bx, cx

        mov byte ptr es:[bx], al

    skip_point:
    pop es
    popa
    pop bp
    ret 6           ; Return and pop 6 bytes from stack
output_pixel endp

; Процедура для обчислення масштабів і максимальної кількості кроків
compute_scale proc near
    push bp         ; Збереження стану регістрів
    mov bp, sp
    pusha
    push ds   

        push DATA_SEG
        pop ds

        ; Обчислення масштабу по осі X
        scale x

        ; Обчислення масштабу по осі Y
        scale y

        ; Обчислення максимальної кількості кроків
        ; max_x_steps = (max_x - min_x) / x_step
        fld max_x		; ST(0) = max_x
        fsub min_x	
        fld x_step
        fdivp st(1), st(0)
        frndint	            	; округлення до цілого
        fistp max_x_steps       ; кількість кроків по осі x 

    pop ds
    popa
    pop bp
    ret 
compute_scale endp

; Процедура для обчислення наступного X значення та перетворення в екранні координати
calc_next_x proc near
    push bp         ; Збереження стану регістрів
    mov bp, sp
    pusha
    push ds   

        push DATA_SEG
        pop ds

        ; Збільшуємо значення X на крок
        fld x_value
        fadd x_step
        fst x_value        ; Зберігаємо нове значення X

        ; Перетворюємо реальне значення X в екранну координату
        fsub min_x          ; Переведення у відносні координати
        fdiv scale_x        ; Масштабування
        frndint	            ; Округлення до цілого
        fistp crt_x         ; Зберігаємо екранну координату X

    pop ds
    popa
    pop bp
    ret 
calc_next_x endp

; Процедура для перетворення значення функції Y в екранну координату
convert_y_to_screen proc near
    push bp         ; Збереження стану регістрів
    mov bp, sp
    pusha
    push ds

        push DATA_SEG
        pop ds

        mov si, [bp + 4]    ; Отримуємо колір для малювання
        mov point_valid, 1  ; За замовчуванням точка валідна

        ; Перевірка чи значення Y в допустимому діапазоні
        fcom min_y          ; Порівняння ST(0) та min_y
        fstsw ax            ; Результат порівняння в ax
        sahf 		    ; Результат порівняння у процесорні флаги
        jc below_range	    ; ST(0) < min_y

        fcom max_y	    ; Порівняння ST(0) та max_y
        fstsw ax            ; Результат порівняння в ax
        sahf                ; Результат порівняння у процесорні флаги
        ja above_range	    ; ST(0) > max_y (zf=cf=0)

        ; Значення Y в допустимому діапазоні
        fsub min_y          ; Переведення у відносні координати
        fdiv scale_y        ; Масштабування
        frndint	            ; Округлення до цілого

        fistp crt_y         ; Зберігаємо екранну координату Y
        mov ax, max_crt_y
        sub ax, crt_y
        mov crt_y, ax	    ; Дзеркальне відображення (верхній край - 0)

        mov print_color, si  ; Встановлюємо колір для малювання
        jmp end_convert

    below_range:
        fistp tmp           ; Очищаємо стек FPU
        mov point_valid, 0  ; Позначаємо точку як невалідну
        mov print_color, out_of_range ; Встановлюємо спеціальний колір для пропуску
        jmp end_convert

    above_range:
        fistp tmp           ; Очищаємо стек FPU
        mov point_valid, 0  ; Позначаємо точку як невалідну
        mov print_color, out_of_range ; Встановлюємо спеціальний колір для пропуску

    end_convert:

    pop ds
    popa
    pop bp
    ret 2       ; Return and pop 2 bytes from stack
convert_y_to_screen endp

; Процедура для малювання осей координат
draw_axes proc near
    push bp         ; Збереження стану регістрів
    mov bp, sp
    pusha
    push ds

        push DATA_SEG
        pop ds

        ; Малюємо вісь X
        ; Знаходимо координату Y = 0 на екрані
        fldz                ; ST(0) = 0 (Y=0)
        fsub min_y          ; Переведення у відносні координати
        fdiv scale_y        ; Масштабування
        frndint	            ; Округлення до цілого
        fistp crt_y         ; Зберігаємо екранну координату Y для осі X
        mov ax, max_crt_y
        sub ax, crt_y
        mov crt_y, ax       ; Дзеркальне відображення

        ; Малюємо горизонтальну лінію осі X
        xor di, di          ; di = 0
    x_axis_loop:
        mov crt_x, di       ; Встановлюємо поточну X координату

        push crt_x
        push crt_y
        push axis_color
        call output_pixel

        inc di
        cmp di, max_crt_x
        jb x_axis_loop      ; Продовжуємо малювання осі X

        ; Малюємо вісь Y
        ; Знаходимо координату X = 0 на екрані
        fldz                ; ST(0) = 0 (X=0)
        fsub min_x          ; Переведення у відносні координати
        fdiv scale_x        ; Масштабування
        frndint	            ; Округлення до цілого
        fistp crt_x         ; Зберігаємо екранну координату X для осі Y

        ; Малюємо вертикальну лінію осі Y
        xor di, di          ; di = 0
    y_axis_loop:
        mov crt_y, di       ; Встановлюємо поточну Y координату

        push crt_x
        push crt_y
        push axis_color
        call output_pixel

        inc di
        cmp di, max_crt_y
        jb y_axis_loop      ; Продовжуємо малювання осі Y

    pop ds
    popa
    pop bp
    ret
draw_axes endp

; Процедура для обчислення і малювання функції 0.7*x^2
draw_x2_component proc near
    push bp         ; Збереження стану регістрів
    mov bp, sp
    pusha
    push ds

        push DATA_SEG
        pop ds

        ; Встановлюємо початкове значення X
        fld min_x
        fstp x_value

        mov di, max_x_steps     ; Лічильник кроків

    x2_loop:
        call calc_next_x        ; Обчислюємо наступне значення X
        
        ; Обчислюємо 0.7*x^2
        fld x_value             ; ST(0) = x
        fmul x_value            ; ST(0) = x^2
        fmul coef_x2            ; ST(0) = 0.7*x^2

        ; Перетворюємо значення функції в екранну координату Y
        push x2_color
        call convert_y_to_screen

        ; Малюємо точку
        push crt_x
        push crt_y
        push print_color
        call output_pixel

        dec di
        jnz x2_loop             ; Продовжуємо малювання, якщо не досягли кінця

    pop ds
    popa
    pop bp
    ret
draw_x2_component endp

; Процедура для обчислення і малювання функції 5.7*x
draw_x_component proc near
    push bp         ; Збереження стану регістрів
    mov bp, sp
    pusha
    push ds

        push DATA_SEG
        pop ds

        ; Встановлюємо початкове значення X
        fld min_x
        fstp x_value

        mov di, max_x_steps     ; Лічильник кроків

    x_loop:
        call calc_next_x        ; Обчислюємо наступне значення X
        
        ; Обчислюємо 5.7*x
        fld x_value             ; ST(0) = x
        fmul coef_x             ; ST(0) = 5.7*x

        ; Перетворюємо значення функції в екранну координату Y
        push x_color
        call convert_y_to_screen

        ; Малюємо точку
        push crt_x
        push crt_y
        push print_color
        call output_pixel

        dec di
        jnz x_loop              ; Продовжуємо малювання, якщо не досягли кінця

    pop ds
    popa
    pop bp
    ret
draw_x_component endp


draw_xy_component proc near
    push bp         ; Збереження стану регістрів
    mov bp, sp
    pusha
    push ds

        push DATA_SEG
        pop ds

        ; Встановлюємо початкове значення X
        fld min_x
        fstp x_value

        mov di, max_x_steps     ; Лічильник кроків

    xy_loop:
        call calc_next_x        ; Обчислюємо наступне значення X
        
        ; Заносимо x
        fld x_value             ; ST(0) = x


        ; Перетворюємо значення функції в екранну координату Y
        push xy_color
        call convert_y_to_screen

        ; Малюємо точку
        push crt_x
        push crt_y
        push print_color
        call output_pixel

        dec di
        jnz xy_loop              ; Продовжуємо малювання, якщо не досягли кінця

    pop ds
    popa
    pop bp
    ret
draw_xy_component endp


; Процедура для обчислення і малювання константи 1
draw_const_component proc near
    push bp         ; Збереження стану регістрів
    mov bp, sp
    pusha
    push ds

        push DATA_SEG
        pop ds

        ; Встановлюємо початкове значення X
        fld min_x
        fstp x_value

        mov di, max_x_steps     ; Лічильник кроків

    const_loop:
        call calc_next_x        ; Обчислюємо наступне значення X
        
        ; Завантажуємо константу 1
        fld coef_const          ; ST(0) = 1.0

        ; Перетворюємо значення функції в екранну координату Y
        push const_color
        call convert_y_to_screen

        ; Малюємо точку
        push crt_x
        push crt_y
        push print_color
        call output_pixel

        dec di
        jnz const_loop          ; Продовжуємо малювання, якщо не досягли кінця

    pop ds
    popa
    pop bp
    ret
draw_const_component endp

; Процедура для обчислення і малювання повної функції 0.7*x^2 + 5.7*x + 1
draw_polynomial proc near
    push bp         ; Збереження стану регістрів
    mov bp, sp
    pusha
    push ds

        push DATA_SEG
        pop ds

        ; Встановлюємо початкове значення X
        fld min_x
        fstp x_value

        mov di, max_x_steps     ; Лічильник кроків

    poly_loop:
        call calc_next_x        ; Обчислюємо наступне значення X
        
        ; Обчислюємо 0.7*x^2 + 5.7*x + 1
        fld x_value             ; ST(0) = x
        fmul x_value            ; ST(0) = x^2
        fmul coef_x2            ; ST(0) = 0.7*x^2
        
        fld x_value             ; ST(0) = x, ST(1) = 0.7*x^2
        fmul coef_x             ; ST(0) = 5.7*x, ST(1) = 0.7*x^2
        faddp st(1), st(0)      ; ST(0) = 0.7*x^2 + 5.7*x
        
        fadd coef_const         ; ST(0) = 0.7*x^2 + 5.7*x + 1

        ; Перетворюємо значення функції в екранну координату Y
        push poly_color
        call convert_y_to_screen

        ; Малюємо точку
        push crt_x
        push crt_y
        push print_color
        call output_pixel

        dec di
        jnz poly_loop           ; Продовжуємо малювання, якщо не досягли кінця

    pop ds
    popa
    pop bp
    ret
draw_polynomial endp

; Головна процедура програми
begin:
    push DATA_SEG
    pop DS

    ; Ініціалізація співпроцесора
    finit

    ; Ініціювання графічного відеорежиму 
    mov ax, 13h                ; 320x200, 256 кольорів
    int 10h 

    ; Обчислюємо масштаби
    call compute_scale

    ; Малюємо осі координат
    call draw_axes

    ; Малюємо компоненти функції окремо
    call draw_x2_component     ; 0.7*x^2
    call draw_x_component      ; 5.7*x
    call draw_xy_component     ; x
    call draw_const_component  ; 1

    ; Малюємо повну функцію
    call draw_polynomial       ; 0.7*x^2 + 5.7*x + 1

    ; Очікування натискання довільної клавіші
    xor ax, ax 	
    int 16h 	

    ; Повернення до текстового режиму
    mov ax, 3 	
    int 10h 	
    
    ; Вихід з програми
    mov ax, 4C00h 	
    int 21h

CODE_SEG ENDS

END begin

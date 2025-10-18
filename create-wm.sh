#!/bin/bash
#set -x

# Проверяем существование файла user-data
if [ -f "user-data" ]; then
    echo "Найден файл user-data. Использую его настройки."
else
    echo "Файл user-data не найден в текущем каталоге. Создайте его по инструкции: https://yandex.cloud/ru/docs/compute/operations/vm-create/create-with-env-variables"
    exit 1
fi

# Функция проверки установленных утилит
check_dependencies() {
    local deps=("yc" "jq")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            echo "Ошибка: $dep не установлен!"
            exit 1
        fi
    done
}

# Функция валидации ввода
validate_input() {
    if [ -z "$1" ]; then
        echo "Неверный ввод. Попробуйте снова."
        exit 1
    fi
}

# Функция для получения ответа прерывания
get_preemptible() {
    local preemptible
    while true; do
        echo "Прерываемая ВМ?"
        echo -n "Введите 'да|y|yes' или 'нет|n|no': "
        read preemptible
        
        # Приводим ответ к нижнему регистру
        case "$(echo "$preemptible" | tr '[:upper:]' '[:lower:]')" in
            да|y|yes)
                PREEMPTIBLE_RESULT="true"
                break
                ;;
            нет|n|no)
                PREEMPTIBLE_RESULT="false"
                break
                ;;
            *)
                echo "Неверный ввод. Пожалуйста, введите 'да|y|yes' или 'нет|n|no':."
                ;;
        esac
    done
}

check_dependencies

# Запрашиваем параметры у пользователя
echo "Введите параметры для виртуальной машины:"

# Имя ВМ
echo ""
read -p "Имя виртуальной машины: " VM_NAME
validate_input "$VM_NAME"

echo ""
read -p "Имя хоста у виртуальной машины: " VM_HOSTNAME
validate_input "$VM_HOSTNAME"

# Зона доступности
echo ""
echo "Выберите зону доступности:"
echo "1 - Ubuntu 24.04 LTS"
echo "2 - Debian 12"
echo "3 - AlmaLinux 9"

read -p "Введите номер (1/2/3): " choice_dstr

case $choice_dstr in
    1) DSTR="ubuntu-2404-lts" ;;
    2) DSTR="debian-12" ;;
    3) DSTR="almalinux-9" ;;
    *) echo "Неверный выбор!"
       exit 1 ;;
esac

# Прерывания ВМ?
echo ""
get_preemptible


# Гарантированная доля vCPU
ALLOWED_VALUES_GARANT=(5 20 50 100)
while true; do
    echo ""
    echo "Гарантированная доля vCPU, доступно:"
    echo "5%, 20%, 50% и 100%."
    read -p "Введите значение(Без %): " CORE_GARANT
    if [[ " ${ALLOWED_VALUES_GARANT[@]} " =~ " ${CORE_GARANT} " ]]; then
        break
    else
        echo "Некорректное значение. Введите целое число, например: 5, 20, 50, 100."
    fi
done

# Определяем допустимые значения 
case $CORE_GARANT in
    5)
        ALLOWED_VALUES=(2 4)
        MSG_VCPU="Гарантированная доля vCPU менее 100%, доступно: 2 и 4."
        ALLOWED_VALUES_MEM=(1 2 3 4)
        MSG_MEM="Гарантированная доля vCPU 5%, доступно: от 1GB до 4GB."
        
        ;;
    20|50)
        ALLOWED_VALUES=(2 4)
        MSG_VCPU="Гарантированная доля vCPU менее 100%, доступно: 2 и 4."
        ALLOWED_VALUES_MEM=(1 2 3 4 5 6 7 8)
        MSG_MEM="Гарантированная доля vCPU 20%/50%, доступно: от 1GB до 8GB."
        ;;
    100)
        ALLOWED_VALUES=(2 4 6 8 10 12 14 16 20 24 28 32 36 40 44 48 52 56 60 64 68 72 76 80)
        MSG_VCPU="Доступно: 2, 4, 6, 8, 10, 12, 14, 16, 20, 24, 28, 32, 36, 40, 44, 48, 52, 56, 60, 64, 68, 72, 76, 80."
        ALLOWED_VALUES_MEM=(2 4 6 8 10 12 14 16 18 20 22 24 26 28 30 32)
        MSG_MEM="Доступно: 2GB, 4GB, 6GB, 8GB, 10GB, 12GB, 14GB, 16GB, 18GB, 20GB, 22GB, 24GB, 26GB, 28GB, 30GB, 32GB." 
        ;;
esac

# Количество ядер
while true; do
    echo ""
    echo "Выберите количество ядер процессора:"
    echo "$MSG_VCPU" 
    read -p "Введите значение: " CORE_COUNT
    if [[ " ${ALLOWED_VALUES[@]} " =~ " ${CORE_COUNT} " ]]; then
        break
    else
        echo "Некорректное значение. Доступные значения: ${ALLOWED_VALUES[*]}"
    fi
done

# Объем памяти
while true; do
    echo ""
    echo "Выберите объем памяти:"
    echo "$MSG_MEM"
    read -p "Введите значение(Без GB): " MEMORY
    if [[ " ${ALLOWED_VALUES_MEM[@]} " =~ " ${MEMORY} " ]]; then
        break
    else
        echo "Некорректное значение. Доступные значения: ${ALLOWED_VALUES_MEM[*]}"
    fi
done

# Размер диска
while true; do
    echo ""
    read -p "Размер диска в GB, не менее 10: " SIZE
    if [[ "$SIZE" =~ ^[1-9][0-9][0-9]*$ ]]; then
        break
    else
        echo "Размер диска должен быть больше или равен 10,0Gb."
    fi
done

# Зона доступности
echo ""
echo "Выберите зону доступности:"
echo "1 - ru-central1-a"
echo "2 - ru-central1-b"
echo "3 - ru-central1-d"

read -p "Введите номер (1/2/3): " choice

case $choice in
    1) ZONE="ru-central1-a" ;;
    2) ZONE="ru-central1-b" ;;
    3) ZONE="ru-central1-d" ;;
    *) echo "Неверный выбор!"
       exit 1 ;;
esac

# Параметры виртуальной машины
NETWORK="default"

# Создаем виртуальную машину
echo ""
echo "Создаем виртуальную машину..."
yc compute instance create \
    --name=$VM_NAME \
    --hostname $VM_HOSTNAME \
    --zone=$ZONE \
    --preemptible=$PREEMPTIBLE_RESULT \
    --create-boot-disk image-folder-id=standard-images,image-family=$DSTR,size="$SIZE"GB,type=network-ssd \
    --memory=$MEMORY \
    --cores=$CORE_COUNT \
    --core-fraction=$CORE_GARANT \
    --network-interface subnet-name=default-"$ZONE",nat-ip-version=ipv4 \
    --metadata enable-serial-port-logging=True \
    --metadata-from-file user-data=user-data \
    --metadata serial-port-enable=1 

# Получаем публичный IP
PUBLIC_IP=$(yc compute instance get "$VM_NAME" --format json | jq -r '.network_interfaces[0].primary_v4_address.one_to_one_nat.address')

echo "Виртуальная машина создана:"
echo "Дистрибутив: $DSTR"
echo "Имя: $VM_NAME"
echo "Имя хоста: $VM_HOSTNAME"
echo "Публичный IP: $PUBLIC_IP"
echo "Зона: $ZONE"
echo "Подсеть: default-"$ZONE""
echo "Прерываемая ВМ: $PREEMPTIBLE_RESULT"
echo "Ресурсы: $CORE_COUNT vCPU, $MEMORY ГБ RAM, Размер диска $SIZE GB"

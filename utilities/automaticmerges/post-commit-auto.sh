#!/usr/bin/env sh
# Ir siempre a la raíz del repo (por si acaso)
cd "$(git rev-parse --show-toplevel)" || exit 1

# Mensaje del último commit (limpia \r por CRLF)
MSG="$(git log -1 --pretty=%B | tr -d '\r')"

echo "husky(post-commit): hook ejecutado correctamente."
echo "husky(post-commit): mensaje del commit -> [$MSG]"

case "$MSG" in
  *"automatic merge from maintenance without propagating develop"*)
    git commit --amend -m "readme: update changelog" --no-edit
    echo "husky(post-commit): mensaje del commit modificado a 'readme: update changelog'."
    bash ./utilities/automaticmerges/nodevelop/automatic-update-nodevelop.sh 
    ;;

  *"automatic merge from maintenance"*)
    echo "husky(post-commit): detectado 'automatic merge from maintenance'. (aquí se ejecutaría utilities/uplog.sh)"
    # Ejemplo: se enmienda el commit y se ejecuta el script de changelog
    git commit --amend -m "readme: update changelog" --no-edit
    echo "husky(post-commit): mensaje del commit modificado a 'readme: update changelog'."
    bash ./utilities/automaticmerges/maintenance/automatic-update-maintenance.sh
    ;;

    *"automatic merge from master-hot-fix"*)
    echo "husky(post-commit): detectado 'automatic merge from master-hot-fix'"
    # Ejemplo: se enmienda el commit y se ejecuta el script de changelog
    git commit --amend -m "readme: update changelog" --no-edit
    echo "husky(post-commit): mensaje del commit modificado a 'readme: update changelog'."
    bash ./utilities/automaticmerges/hot-fix-master/automatic-update-hot-fix-master.sh
    ;;

    *"automatic merge from hot-fix"*)
    echo "husky(post-commit): detectado 'automatic merge from hot-fix'"
    # Ejemplo: se enmienda el commit y se ejecuta el script de changelog
    git commit --amend -m "readme: update changelog" --no-edit
    echo "husky(post-commit): mensaje del commit modificado a 'readme: update changelog'."
    bash ./utilities/automaticmerges/hot-fix/automatic-update-hot-fix.sh
    ;;    

  *)
    echo "husky(post-commit): no se detecta 'run script'."
    ;;
esac

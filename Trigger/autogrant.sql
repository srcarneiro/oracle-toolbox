/*
Autor: Sérgio Carneiro
Data: Fev/2012

Motivação: 
	Busca simplificar o gerenciamento de permissões entre schemas/users onde
	um usuário primário (Servindo de repositório de objetos)
	concede automaticamente privilégios pré-estabelecidos pelo administrador e,
	quando conveniente, também cria automaticamente sinônimos apontando para tais
	objetos. 
	
Exemplo:
	-> Tomando como exemplo a criação do seguinte objeto
	CREATE TABLE USUARIO_PRIMARIO.TABELA (ID NUMBER);
	
	-> A trigger pderá pode conceder, automaticamente, as seguintes permissões, se assim for
	   da necessidade do administrador
	
	# Permissões e sinônimos para um usuário que é utilizado pela aplicação
	GRANT SELECT,REFERENCES,INSERT,UPDATE,DELETE ON USUARIO_SECUNDARIO_1.TABELA;
	CREATE SYNONYM.USUARIO_SECUNDARIO_1.TABELA FOR USUARIO_PRIMARIO.TABELA;
	
	# Permissões apenas, para um usuário que é utilizado somente para consulta
	GRANT SELECT,REFERENCES ON USUARIO_SECUNDARIO_2.TABELA;
	
Observação:
	Deve ser criado com o usuário SYS
	
*/
CREATE OR REPLACE TRIGGER SYS.AUTOGRANT
AFTER CREATE OR DROP
ON DATABASE
DECLARE

TYPE TTGRANT IS TABLE OF VARCHAR2(4000) INDEX BY VARCHAR(40);
tbGrant TTGRANT;

usrOwner VARCHAR2(4000);
usrGrantee VARCHAR2(4000);

-- Cria uma tarefa temporária para executar o comando de permissionamento
PROCEDURE sendDDL (pCmd varchar2) IS
vSchedulerName VARCHAR2(200) := 'AUTOGRANT_'||DBMS_RANDOM.string('x',10);
BEGIN


DBMS_SCHEDULER.create_job (
         job_name          => vSchedulerName,
         job_type          => 'PLSQL_BLOCK',
         job_action        => 'BEGIN EXECUTE IMMEDIATE '''||pCmd||'''; END;',
         start_date        => SYSDATE,
         repeat_interval   => NULL,
         end_date          => NULL,
         auto_drop         => TRUE,
         enabled           => TRUE,
         comments          => NULL);
DBMS_OUTPUT.PUT_LINE(pCmd);



END;

-- Cria um sinônimo para o objeto criado
PROCEDURE checkDDL (pOwner VARCHAR2, pGrantee VARCHAR2,pCmd TTGRANT,pSynonym boolean)
IS
   vObject   VARCHAR2 (4000);
   vSynonym VARCHAR2 (4000) := 'CREATE SYNONYM ' || pGrantee || '.'||ora_dict_obj_name||' FOR ' || pOwner ||'.'||ora_dict_obj_name;
BEGIN
   IF ora_sysevent = 'CREATE' AND ora_dict_obj_owner = pOwner
   THEN
      vObject := pCmd.FIRST;

      WHILE vObject IS NOT NULL
      LOOP

         IF vObject = ora_dict_obj_type THEN
             sendDDL(pCmd (vObject));
         END IF;


         IF vObject = ora_dict_obj_type and pSynonym
         THEN
            sendDDL(vSynonym);
         END IF;


         vObject := pCmd.NEXT (vObject);
      END LOOP;
   END IF;
END checkDDL;

BEGIN

-- Primeira regra de permissão estabelecida pelo administrador
usrOwner:='USUARIO_PRIMARIO';
usrGrantee:='USUARIO_SECUNDARIO_1';
tbGrant('TABLE'):='GRANT SELECT,REFERENCES,INSERT,UPDATE,DELETE ON '|| ora_dict_obj_owner ||'.' || ora_dict_obj_name || ' TO ' || usrGrantee;
tbGrant('VIEW'):='GRANT SELECT ON '|| ora_dict_obj_owner ||'.' || ora_dict_obj_name || ' TO ' || usrGrantee;
tbGrant('SEQUENCE'):='GRANT SELECT ON '|| ora_dict_obj_owner ||'.' || ora_dict_obj_name || ' TO ' || usrGrantee;
tbGrant('PROCEDURE'):='GRANT EXECUTE,DEBUG ON '|| ora_dict_obj_owner ||'.' || ora_dict_obj_name || ' TO ' || usrGrantee;
tbGrant('FUNCTION'):='GRANT EXECUTE,DEBUG ON '|| ora_dict_obj_owner ||'.' || ora_dict_obj_name || ' TO ' || usrGrantee;
tbGrant('PACKAGE'):='GRANT EXECUTE,DEBUG ON '|| ora_dict_obj_owner ||'.' || ora_dict_obj_name || ' TO ' || usrGrantee;
checkDDL(usrOwner,usrGrantee, tbGrant,true);
tbGrant.Delete();

-- Segunda regra de permissão estabelecida pelo administrador
usrOwner:='USUARIO_PRIMARIO';
usrGrantee:='USUARIO_SECUNDARIO_2';
tbGrant('TABLE'):='GRANT SELECT,REFERENCES ON '|| ora_dict_obj_owner ||'.' || ora_dict_obj_name || ' TO ' || usrGrantee;
tbGrant('VIEW'):='GRANT SELECT ON '|| ora_dict_obj_owner ||'.' || ora_dict_obj_name || ' TO ' || usrGrantee;
tbGrant('SEQUENCE'):='GRANT SELECT ON '|| ora_dict_obj_owner ||'.' || ora_dict_obj_name || ' TO ' || usrGrantee;
tbGrant('PROCEDURE'):='GRANT EXECUTE ON '|| ora_dict_obj_owner ||'.' || ora_dict_obj_name || ' TO ' || usrGrantee;
tbGrant('FUNCTION'):='GRANT EXECUTE ON '|| ora_dict_obj_owner ||'.' || ora_dict_obj_name || ' TO ' || usrGrantee;
tbGrant('PACKAGE'):='GRANT EXECUTE ON '|| ora_dict_obj_owner ||'.' || ora_dict_obj_name || ' TO ' || usrGrantee;
checkDDL(usrOwner,usrGrantee, tbGrant,true);
tbGrant.Delete();

-- Demais regras de permissão 
-- (...)

END AUTOGRANT;
/

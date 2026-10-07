CREATE TABLE alunos (
    aluno_id NUMBER GENERATED ALWAYS AS IDENTITY,
    nome VARCHAR2(100) NOT NULL,
    email VARCHAR2(150) NOT NULL,
    ativo CHAR(1) DEFAULT 'S' NOT NULL,
    data_cadastro DATE DEFAULT SYSDATE NOT NULL,
    CONSTRAINT pk_alunos PRIMARY KEY (aluno_id),
    CONSTRAINT uk_alunos_email UNIQUE (email),
    CONSTRAINT ck_alunos_ativo CHECK (ativo IN ('S', 'N'))
);

CREATE TABLE cursos (
    curso_id NUMBER GENERATED ALWAYS AS IDENTITY,
    nome VARCHAR2(100) NOT NULL,
    carga_horaria NUMBER(4) NOT NULL,
    quantidade_vagas NUMBER(4) NOT NULL,
    ativo CHAR(1) DEFAULT 'S' NOT NULL,
    CONSTRAINT pk_cursos PRIMARY KEY (curso_id),
    CONSTRAINT ck_cursos_carga CHECK (carga_horaria > 0),
    CONSTRAINT ck_cursos_vagas CHECK (quantidade_vagas > 0),
    CONSTRAINT ck_cursos_ativo CHECK (ativo IN ('S', 'N'))
);

CREATE TABLE matriculas (
    matricula_id NUMBER GENERATED ALWAYS AS IDENTITY,
    aluno_id NUMBER NOT NULL,
    curso_id NUMBER NOT NULL,
    data_matricula DATE DEFAULT SYSDATE NOT NULL,
    nota NUMBER(4,2),
    situacao VARCHAR2(20) DEFAULT 'EM_CURSO' NOT NULL,
    CONSTRAINT pk_matriculas PRIMARY KEY (matricula_id),
    CONSTRAINT fk_matriculas_alunos
        FOREIGN KEY (aluno_id) REFERENCES alunos (aluno_id),
    CONSTRAINT fk_matriculas_cursos
        FOREIGN KEY (curso_id) REFERENCES cursos (curso_id),
    CONSTRAINT uk_aluno_curso UNIQUE (aluno_id, curso_id),
    CONSTRAINT ck_matriculas_nota CHECK (nota BETWEEN 0 AND 10),
    CONSTRAINT ck_matriculas_situacao
        CHECK (situacao IN ('EM_CURSO', 'APROVADO', 'REPROVADO', 'CANCELADO'))
);

INSERT INTO cursos (nome, carga_horaria, quantidade_vagas)
VALUES ('Introdução ao SQL', 40, 3);

INSERT INTO cursos (nome, carga_horaria, quantidade_vagas)
VALUES ('Programação PL/SQL', 60, 2);

CREATE OR REPLACE PROCEDURE cadastrar_aluno (
    p_nome IN VARCHAR2,
    p_email IN VARCHAR2
)
IS
    v_aluno_id alunos.aluno_id%TYPE;
BEGIN
    IF LENGTH(TRIM(p_nome)) < 3 THEN
        RAISE_APPLICATION_ERROR(
            -20001,
            'O nome deve possuir pelo menos 3 caracteres.'
        );
    END IF;

    IF p_email IS NULL OR INSTR(p_email, '@') = 0 THEN
        RAISE_APPLICATION_ERROR(
            -20002,
            'Informe um e-mail válido.'
        );
    END IF;

    INSERT INTO alunos (nome, email)
    VALUES (TRIM(p_nome), LOWER(TRIM(p_email)))
    RETURNING aluno_id INTO v_aluno_id;

    DBMS_OUTPUT.PUT_LINE(
        'Aluno cadastrado. Código: ' || v_aluno_id
    );

EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        RAISE_APPLICATION_ERROR(
            -20003,
            'Já existe um aluno com esse e-mail.'
        );
END cadastrar_aluno;
/

BEGIN
    cadastrar_aluno(
        p_nome => 'Ana Silva',
        p_email => 'ana@escola.com'
    );
END;
/

BEGIN
    cadastrar_aluno(
        p_nome => 'Bruno Souza',
        p_email => 'bruno@escola.com'
    );
END;
/

BEGIN
    cadastrar_aluno(
        p_nome => 'Carlos Oliveira',
        p_email => 'carlos@escola.com'
    );
END;
/

BEGIN
    cadastrar_aluno(
        p_nome => 'Mariana Santos',
        p_email => 'mariana@escola.com'
    );
END;
/

CREATE OR REPLACE PROCEDURE matricular_aluno (
    p_aluno_id IN NUMBER,
    p_curso_id IN NUMBER
)
IS
    v_aluno_ativo alunos.ativo%TYPE;
    v_curso_ativo cursos.ativo%TYPE;
    v_total_vagas cursos.quantidade_vagas%TYPE;
    v_total_matriculas NUMBER;
    v_matricula_id matriculas.matricula_id%TYPE;
BEGIN
    BEGIN
        SELECT ativo
        INTO v_aluno_ativo
        FROM alunos
        WHERE aluno_id = p_aluno_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(
                -20010,
                'Aluno não encontrado.'
            );
    END;

    IF v_aluno_ativo = 'N' THEN
        RAISE_APPLICATION_ERROR(
            -20011,
            'O aluno está inativo.'
        );
    END IF;

    BEGIN
        SELECT ativo, quantidade_vagas
        INTO v_curso_ativo, v_total_vagas
        FROM cursos
        WHERE curso_id = p_curso_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(
                -20012,
                'Curso não encontrado.'
            );
    END;

    IF v_curso_ativo = 'N' THEN
        RAISE_APPLICATION_ERROR(
            -20013,
            'O curso está inativo.'
        );
    END IF;

    SELECT COUNT(*)
    INTO v_total_matriculas
    FROM matriculas
    WHERE curso_id = p_curso_id
    AND situacao <> 'CANCELADO';

    IF v_total_matriculas >= v_total_vagas THEN
        RAISE_APPLICATION_ERROR(
            -20014,
            'Não existem vagas disponíveis.'
        );
    END IF;

    INSERT INTO matriculas (aluno_id, curso_id)
    VALUES (p_aluno_id, p_curso_id)
    RETURNING matricula_id INTO v_matricula_id;

    DBMS_OUTPUT.PUT_LINE(
        'Matrícula realizada. Código: ' || v_matricula_id
    );

EXCEPTION
    WHEN DUP_VAL_ON_INDEX THEN
        RAISE_APPLICATION_ERROR(
            -20015,
            'O aluno já está matriculado neste curso.'
        );
END matricular_aluno;
/

BEGIN
    matricular_aluno(
        p_aluno_id => 1,
        p_curso_id => 1
    );
END;
/

BEGIN
    matricular_aluno(
        p_aluno_id => 2,
        p_curso_id => 1
    );
END;
/

BEGIN
    matricular_aluno(
        p_aluno_id => 3,
        p_curso_id => 2
    );
END;
/

BEGIN
    matricular_aluno(
        p_aluno_id => 4,
        p_curso_id => 2
    );
END;
/

CREATE OR REPLACE PROCEDURE registrar_nota (
    p_matricula_id IN NUMBER,
    p_nota IN NUMBER
)
IS
    v_situacao matriculas.situacao%TYPE;
    v_nova_situacao matriculas.situacao%TYPE;
BEGIN
    IF p_nota IS NULL OR p_nota < 0 OR p_nota > 10 THEN
        RAISE_APPLICATION_ERROR(
            -20020,
            'A nota deve estar entre 0 e 10.'
        );
    END IF;

    BEGIN
        SELECT situacao
        INTO v_situacao
        FROM matriculas
        WHERE matricula_id = p_matricula_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(
                -20021,
                'Matrícula não encontrada.'
            );
    END;

    IF v_situacao = 'CANCELADO' THEN
        RAISE_APPLICATION_ERROR(
            -20022,
            'Uma matrícula cancelada não pode receber nota.'
        );
    END IF;

    IF p_nota >= 7 THEN
        v_nova_situacao := 'APROVADO';
    ELSE
        v_nova_situacao := 'REPROVADO';
    END IF;

    UPDATE matriculas
    SET nota = p_nota,
        situacao = v_nova_situacao
    WHERE matricula_id = p_matricula_id;

    DBMS_OUTPUT.PUT_LINE(
        'Nota registrada. Situação: ' || v_nova_situacao
    );
END registrar_nota;
/

BEGIN
    registrar_nota(
        p_matricula_id => 1,
        p_nota => 8.5
    );
END;
/

BEGIN
    cadastrar_aluno(
        p_nome => 'Jo',
        p_email => 'jo@escola.com'
    );
END;
/

BEGIN
    cadastrar_aluno(
        p_nome => 'Joao Silva',
        p_email => 'joao.escola.com'
    );
END;
/

BEGIN
    cadastrar_aluno(
        p_nome => 'Outra Ana',
        p_email => 'ana@escola.com'
    );
END;
/

BEGIN
    matricular_aluno(
        p_aluno_id => 1,
        p_curso_id => 1
    );
END;
/

BEGIN
    matricular_aluno(
        p_aluno_id => 1,
        p_curso_id => 2
    );
END;
/

BEGIN
    registrar_nota(
        p_matricula_id => 1,
        p_nota => 11
    );
END;
/

CREATE OR REPLACE PROCEDURE cancelar_matricula (
    p_matricula_id IN NUMBER
)
IS
    v_situacao matriculas.situacao%TYPE;
BEGIN
    SELECT situacao
    INTO v_situacao
    FROM matriculas
    WHERE matricula_id = p_matricula_id;

    IF v_situacao = 'CANCELADO' THEN
        RAISE_APPLICATION_ERROR(
            -20030,
            'A matrícula já está cancelada.'
        );
    END IF;

    UPDATE matriculas
    SET situacao = 'CANCELADO'
    WHERE matricula_id = p_matricula_id;

    DBMS_OUTPUT.PUT_LINE(
        'Matrícula ' || p_matricula_id ||
        ' cancelada com sucesso.'
    );

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(
            -20031,
            'Matrícula não encontrada.'
        );
END cancelar_matricula;
/

BEGIN
    cancelar_matricula(
        p_matricula_id => 1
    );
END;
/

BEGIN
    cancelar_matricula(
        p_matricula_id => 1
    );
END;
/

BEGIN
    cancelar_matricula(
        p_matricula_id => 999
    );
END;
/

SELECT
    aluno_id,
    nome,
    email,
    ativo,
    data_cadastro
FROM alunos
ORDER BY aluno_id;

SELECT
    curso_id,
    nome,
    carga_horaria,
    quantidade_vagas,
    ativo
FROM cursos
ORDER BY curso_id;

SELECT
    matricula_id,
    aluno_id,
    curso_id,
    data_matricula,
    nota,
    situacao
FROM matriculas
ORDER BY matricula_id;

SELECT
    m.matricula_id,
    a.nome AS aluno,
    c.nome AS curso,
    c.carga_horaria,
    m.data_matricula,
    m.nota,
    m.situacao
FROM matriculas m
JOIN alunos a
    ON a.aluno_id = m.aluno_id
JOIN cursos c
    ON c.curso_id = m.curso_id
ORDER BY m.matricula_id;

COMMIT;
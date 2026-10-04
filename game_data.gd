extends RefCounted

const STAT_NAMES = {"max_hp": "최대 체력", "max_mp": "최대 마력", "patk": "물공",
	"pdef": "물방", "matk": "마공", "mdef": "마방", "speed": "속도"}
const HEROES = {
	"leon": {"name": "레온", "tile": 96, "stats": [36, 7, 8, 3, 3, 2, 8], "skill": "guard", "role": "전열 · 방어막"},
	"ria": {"name": "리아", "tile": 99, "stats": [28, 8, 9, 2, 3, 2, 11], "skill": "shot", "role": "물리 · 빠른 공격"},
	"mira": {"name": "미라", "tile": 84, "stats": [27, 12, 4, 2, 8, 4, 9], "skill": "heal", "role": "치유 · 마법 성장"},
	"orin": {"name": "오린", "tile": 97, "stats": [40, 9, 7, 4, 3, 3, 6], "skill": "rally", "role": "수호 · 파티 방어막"},
	"sera": {"name": "세라", "tile": 85, "stats": [26, 12, 4, 1, 10, 3, 10], "skill": "spark", "role": "마법 · 높은 화력"}
}
const SKILLS = {
	"guard": {"name": "수호의 빛", "cost": 2, "kind": "shield", "power": 12.0, "description": "자신에게 방어막 12", "bonus": {"pdef": 1}},
	"shot": {"name": "관통 사격", "cost": 2, "kind": "physical", "power": 1.6, "description": "선두 적 · 물공 ×1.6", "bonus": {"patk": 1}},
	"heal": {"name": "회복의 기도", "cost": 3, "kind": "heal", "power": 1.6, "description": "약한 아군 · 마공 ×1.6 치유", "bonus": {"matk": 1}},
	"spark": {"name": "잔불 화살", "cost": 3, "kind": "magic", "power": 1.7, "description": "선두 적 · 마공 ×1.7", "bonus": {"matk": 2, "max_mp": 2}},
	"cleave": {"name": "회전 베기", "cost": 3, "kind": "physical_all", "power": 1.0, "description": "적 전체 · 물공 ×1.0", "bonus": {"patk": 2}},
	"nova": {"name": "별의 파동", "cost": 4, "kind": "magic_all", "power": 1.1, "description": "적 전체 · 마공 ×1.1", "bonus": {"matk": 2, "max_mp": 1}},
	"drain": {"name": "생명 흡수", "cost": 3, "kind": "drain", "power": 1.5, "description": "마공 ×1.5 · 준 피해의 절반 자가 치유", "bonus": {"matk": 1, "max_hp": 4}},
	"rally": {"name": "수호의 맹세", "cost": 3, "kind": "party_shield", "power": 7.0, "description": "생존 아군 모두 방어막 7", "bonus": {"pdef": 1, "mdef": 1}},
	"renew": {"name": "회복의 물결", "cost": 4, "kind": "party_heal", "power": 1.0, "description": "생존 아군 모두 마공 ×1.0 치유", "bonus": {"max_mp": 3, "mdef": 1}},
	"quick": {"name": "질풍 찌르기", "cost": 1, "kind": "physical", "power": 1.2, "description": "선두 적 · 물공 ×1.2", "bonus": {"speed": 2}},
	"pierce": {"name": "갑옷 가르기", "cost": 4, "kind": "pierce", "power": 1.8, "description": "선두 적 · 물공 ×1.8 · 물방 무시", "bonus": {"patk": 2, "max_hp": 2}},
	"barrier": {"name": "비전 장벽", "cost": 2, "kind": "magic_shield", "power": 2.0, "description": "선두 아군에게 마공 ×2 방어막", "bonus": {"mdef": 2, "max_mp": 2}}
}
const GEAR = {
	"sword": {"name": "청동 검", "slot": "weapon", "bonus": {"patk": 3}, "price": 28},
	"staff": {"name": "잿빛 지팡이", "slot": "weapon", "bonus": {"matk": 3}, "price": 28},
	"bow": {"name": "사냥꾼의 활", "slot": "weapon", "bonus": {"patk": 2, "speed": 1}, "price": 28},
	"focus": {"name": "달빛 성물", "slot": "weapon", "bonus": {"matk": 1, "max_mp": 5}, "price": 25},
	"shield": {"name": "철제 방패", "slot": "armor", "bonus": {"pdef": 2, "max_hp": 4}, "price": 26},
	"robe": {"name": "별무늬 로브", "slot": "armor", "bonus": {"mdef": 3, "max_mp": 3}, "price": 26},
	"boots": {"name": "바람의 장화", "slot": "armor", "bonus": {"speed": 3, "pdef": 1}, "price": 26},
	"mail": {"name": "수호자의 갑옷", "slot": "armor", "bonus": {"pdef": 3, "max_hp": 6, "speed": -1}, "price": 30}
}
const FOES = {
	"sentinel": {"name": "망령 파수병", "tile": 121, "stats": [28, 0, 8, 2, 0, 1, 7], "kind": "front"},
	"ember": {"name": "잔불 술사", "tile": 110, "stats": [23, 0, 4, 1, 8, 2, 10], "kind": "mage"},
	"raider": {"name": "그림자 도적", "tile": 108, "stats": [24, 0, 8, 1, 0, 1, 12], "kind": "weak"},
	"golem": {"name": "석조 수호자", "tile": 120, "stats": [32, 0, 9, 5, 0, 0, 5], "kind": "front"},
	"wisp": {"name": "떠도는 불빛", "tile": 111, "stats": [22, 0, 3, 0, 8, 5, 11], "kind": "mage"},
	"warden": {"name": "심연의 문지기", "tile": 122, "stats": [78, 0, 15, 4, 13, 4, 9], "kind": "boss"}
}
const FLOORS = ["잊힌 초소", "메아리 회랑", "심연의 문"]
const ROUTES = {
	"cache": {"name": "버려진 보급함", "description": "장비 3개 중 하나를 원하는 캐릭터에게 지급"},
	"supply": {"name": "피난민의 쉼터", "description": "식량 +1 · 골드 +8"},
	"spring": {"name": "푸른 샘", "description": "생존 아군 최대 마력의 40% 회복 · 식량 +1"},
	"shop": {"name": "떠돌이 상인", "description": "스킬 · 장비 · 식량 구매, 수령인에게 즉시 적용"},
	"shrine": {"name": "망각의 제단", "description": "한 캐릭터의 스킬 하나 해제 · 골드 +12"}
}
const REST_EVENTS = [
	{"name": "별빛 아래의 이야기", "description": "동료의 이야기가 마음을 단단하게 합니다.", "bonus": {"mdef": 1, "max_mp": 1}},
	{"name": "새벽 경계", "description": "밤을 지키며 감각이 예리해집니다. 대신 마력 그릇이 작아집니다.", "bonus": {"speed": 2, "max_mp": -1}},
	{"name": "낡은 지도의 발견", "description": "약점을 파악해 다음 여정을 준비합니다.", "bonus": {"patk": 1, "matk": 1}},
	{"name": "동료의 격려", "description": "긴장하던 몸에 다시 힘이 돌아옵니다. 최대 체력만 증가합니다.", "bonus": {"max_hp": 4}},
	{"name": "고요한 밤", "description": "차분해진 마음으로 마력을 더 담아냅니다.", "bonus": {"max_mp": 2}}
]
